#!/usr/bin/env python3
"""
collect_puf_data.py

Differential Pair Collection Strategy:
  - Compares only within co-located pairs: (0,1), (2,3), ..., (30,31)
  - Runs NUM_ROUNDS rounds of all 16 pair challenges
  - Logs results with Round_Num for reliability analysis

Requires: pip install pyserial
"""

import serial
import time
import csv
import sys
from datetime import datetime

# --- CONFIGURATION ---
PORT = 'COM3'  # Change 'COM3' to match the port found in your Windows Device Manager
BAUD_RATE = 115200
NUM_RO = 32             # Must match FPGA NUM_RO
NUM_PAIRS = NUM_RO // 2 # 16 differential pairs
NUM_ROUNDS = 100        # Number of times to repeat all 16 challenges
CNT_WIDTH_BYTES = 4     # 32-bit counter = 4 bytes
TOTAL_RAW_BYTES = NUM_RO * CNT_WIDTH_BYTES
BOARD_ID = "ARTIX7_BOARD_1"
CSV_FILENAME = "puf_data.csv"

def main():
    print(f"Opening {PORT} at {BAUD_RATE} baud...")
    try:
        ser = serial.Serial(PORT, BAUD_RATE, timeout=5.0)
    except Exception as e:
        print(f"Error opening serial port: {e}")
        sys.exit(1)

    # Allow time for serial connection to settle
    time.sleep(1)
    
    # Open CSV for appending
    file_exists = False
    try:
        with open(CSV_FILENAME, 'r') as f:
            file_exists = True
    except FileNotFoundError:
        pass

    with open(CSV_FILENAME, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        
        # Write header if new file
        if not file_exists:
            writer.writerow(["Timestamp", "Board_ID", "Round_Num", "Pair_Idx",
                             "Sel_A", "Sel_B", "Response", "Raw_Counts"])

        trial_num = 0
        total_trials = NUM_PAIRS * NUM_ROUNDS
        
        print(f"Starting differential pair sweep ({NUM_PAIRS} pairs x {NUM_ROUNDS} rounds = {total_trials} trials)...")
        
        for round_num in range(1, NUM_ROUNDS + 1):
            for pair_idx in range(NUM_PAIRS):
                sel_a = pair_idx * 2
                sel_b = pair_idx * 2 + 1
                
                # Send challenge
                ser.write(bytes([sel_a]))
                ser.write(bytes([sel_b]))
                
                # Read response (1 byte)
                resp_bytes = ser.read(1)
                if len(resp_bytes) != 1:
                    print(f"Timeout waiting for response: Round={round_num}, Pair={pair_idx}")
                    continue
                response_val = resp_bytes[0]
                
                # Read raw counts (NUM_RO * CNT_WIDTH_BYTES bytes)
                raw_bytes = ser.read(TOTAL_RAW_BYTES)
                if len(raw_bytes) != TOTAL_RAW_BYTES:
                    print(f"Timeout waiting for raw counts: Round={round_num}, Pair={pair_idx}")
                    continue
                
                # Unpack raw counts (little-endian per FPGA implementation)
                raw_counts = []
                for i in range(NUM_RO):
                    ro_bytes = raw_bytes[i*CNT_WIDTH_BYTES : (i+1)*CNT_WIDTH_BYTES]
                    count_val = int.from_bytes(ro_bytes, byteorder='little')
                    raw_counts.append(count_val)
                
                # Log to CSV
                timestamp = datetime.now().isoformat()
                raw_counts_str = "[" + ", ".join(str(c) for c in raw_counts) + "]"
                
                writer.writerow([timestamp, BOARD_ID, round_num, pair_idx,
                                 sel_a, sel_b, response_val, raw_counts_str])
                csvfile.flush()
                
                trial_num += 1
                print(f"Round {round_num:3}/{NUM_ROUNDS} | Pair {pair_idx:2} (RO{sel_a} vs RO{sel_b}) | Resp={response_val} | "
                      f"Count_A={raw_counts[sel_a]:>10}, Count_B={raw_counts[sel_b]:>10} | "
                      f"[{trial_num}/{total_trials}]")
                
                # Small delay to not overwhelm the UART buffer
                time.sleep(0.01)
            
            # Print round summary
            print(f"--- Round {round_num} complete ---")

    ser.close()
    print(f"\nSweep complete. {trial_num} trials saved to {CSV_FILENAME}")

if __name__ == "__main__":
    main()
