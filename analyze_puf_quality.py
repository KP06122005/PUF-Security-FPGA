#!/usr/bin/env python3
"""
analyze_puf_quality.py

Computes all four standard PUF quality metrics from collected CSV data:
  1. Uniqueness    (Inter-device Hamming Distance)  - Ideal: 50%
  2. Reliability   (Intra-device Hamming Distance)  - Ideal: 0%
  3. Uniformity    (Proportion of 1s)               - Ideal: 50%
  4. Bit-aliasing  (Per-bit average across devices)  - Ideal: 50%

Usage:
  python analyze_puf_quality.py <file1.csv> [file2.csv]
  
  - Single file:  computes Reliability and Uniformity
  - Two files:    also computes Uniqueness and Bit-aliasing
"""

import csv
import ast
import sys
import math

def load_differential_data(filename):
    """Load CSV and return dict: {(round, pair_idx): response}"""
    data = {}
    with open(filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            round_num = int(row['Round_Num'])
            pair_idx = int(row['Pair_Idx'])
            response = int(row['Response'])
            data[(round_num, pair_idx)] = response
    return data

def get_response_vector(data, round_num, num_pairs=16):
    """Extract the 16-bit response vector for a given round."""
    return [data.get((round_num, p), -1) for p in range(num_pairs)]

def hamming_distance(v1, v2):
    """Compute fractional Hamming distance between two bit vectors."""
    assert len(v1) == len(v2)
    diffs = sum(1 for a, b in zip(v1, v2) if a != b)
    return diffs / len(v1) * 100

def compute_reliability(data, num_pairs=16):
    """
    Intra-device Hamming Distance:
    Compare each round's response vector against the reference (Round 1).
    Ideal: 0% (every round produces the same response).
    """
    rounds = sorted(set(r for r, p in data.keys()))
    if len(rounds) < 2:
        return None, []
    
    ref = get_response_vector(data, rounds[0], num_pairs)
    hds = []
    for r in rounds[1:]:
        vec = get_response_vector(data, r, num_pairs)
        hds.append(hamming_distance(ref, vec))
    
    avg = sum(hds) / len(hds)
    return avg, hds

def compute_uniformity(data, num_pairs=16):
    """
    Proportion of 1s across all responses.
    Ideal: 50% (no bias toward 0 or 1).
    """
    responses = list(data.values())
    ones = sum(responses)
    total = len(responses)
    return (ones / total) * 100

def compute_uniqueness(data1, data2, num_pairs=16):
    """
    Inter-device Hamming Distance:
    Compare Round 1 response vectors between two devices.
    Ideal: 50% (devices are completely independent).
    """
    rounds1 = sorted(set(r for r, p in data1.keys()))
    rounds2 = sorted(set(r for r, p in data2.keys()))
    
    # Compare across all common rounds and average
    common_rounds = min(len(rounds1), len(rounds2))
    hds = []
    for i in range(common_rounds):
        v1 = get_response_vector(data1, rounds1[i], num_pairs)
        v2 = get_response_vector(data2, rounds2[i], num_pairs)
        hds.append(hamming_distance(v1, v2))
    
    avg = sum(hds) / len(hds)
    return avg, hds

def compute_bit_aliasing(data1, data2, num_pairs=16):
    """
    Per-bit average across devices.
    For each bit position, average the response across both devices and all rounds.
    Ideal: 50% for every bit.
    """
    results = []
    for p in range(num_pairs):
        vals = []
        for (r, pi), resp in data1.items():
            if pi == p:
                vals.append(resp)
        for (r, pi), resp in data2.items():
            if pi == p:
                vals.append(resp)
        avg = sum(vals) / len(vals) * 100 if vals else 0
        results.append(avg)
    return results

def mean(data):
    return sum(data) / len(data) if data else 0

def stddev(data):
    if len(data) < 2:
        return 0
    m = mean(data)
    variance = sum((x - m) ** 2 for x in data) / len(data)
    return math.sqrt(variance)

def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_puf_quality.py <file1.csv> [file2.csv]")
        sys.exit(1)
    
    file1 = sys.argv[1]
    file2 = sys.argv[2] if len(sys.argv) > 2 else None
    
    print(f"Loading Device 1: {file1}")
    data1 = load_differential_data(file1)
    rounds1 = sorted(set(r for r, p in data1.keys()))
    pairs1 = sorted(set(p for r, p in data1.keys()))
    print(f"  Rounds: {len(rounds1)}, Pairs: {len(pairs1)}, Total entries: {len(data1)}")
    
    # --- Metric 1: Uniformity ---
    uniformity1 = compute_uniformity(data1)
    print(f"\n{'='*60}")
    print(f" UNIFORMITY (Ideal: 50%)")
    print(f"{'='*60}")
    print(f"  Device 1: {uniformity1:.2f}%")
    
    if file2:
        data2 = load_differential_data(file2)
        uniformity2 = compute_uniformity(data2)
        print(f"  Device 2: {uniformity2:.2f}%")
    
    # --- Metric 2: Reliability ---
    reliability1, rel_hds1 = compute_reliability(data1)
    print(f"\n{'='*60}")
    print(f" RELIABILITY (Intra-Device HD, Ideal: 0%)")
    print(f"{'='*60}")
    if reliability1 is not None:
        print(f"  Device 1: {reliability1:.2f}% (std: {stddev(rel_hds1):.2f}%)")
        print(f"    Min: {min(rel_hds1):.2f}%, Max: {max(rel_hds1):.2f}%")
        flipped_rounds = sum(1 for h in rel_hds1 if h > 0)
        print(f"    Rounds with bit flips: {flipped_rounds}/{len(rel_hds1)}")
    else:
        print(f"  Device 1: Cannot compute (need multiple rounds)")
    
    if file2:
        reliability2, rel_hds2 = compute_reliability(data2)
        if reliability2 is not None:
            print(f"  Device 2: {reliability2:.2f}% (std: {stddev(rel_hds2):.2f}%)")
            print(f"    Min: {min(rel_hds2):.2f}%, Max: {max(rel_hds2):.2f}%")
    
    # --- Metric 3: Uniqueness ---
    if file2:
        uniqueness, uniq_hds = compute_uniqueness(data1, data2)
        print(f"\n{'='*60}")
        print(f" UNIQUENESS (Inter-Device HD, Ideal: 50%)")
        print(f"{'='*60}")
        print(f"  Average: {uniqueness:.2f}% (std: {stddev(uniq_hds):.2f}%)")
        print(f"  Min: {min(uniq_hds):.2f}%, Max: {max(uniq_hds):.2f}%")
    
    # --- Metric 4: Bit-Aliasing ---
    if file2:
        aliasing = compute_bit_aliasing(data1, data2)
        print(f"\n{'='*60}")
        print(f" BIT-ALIASING (Per-Bit Average, Ideal: 50%)")
        print(f"{'='*60}")
        for i, a in enumerate(aliasing):
            status = "OK" if 20 < a < 80 else "BIASED"
            print(f"  Pair {i:2d} (RO{i*2:2d} vs RO{i*2+1:2d}): {a:6.2f}%  [{status}]")
        avg_alias = mean(aliasing)
        print(f"  Overall average: {avg_alias:.2f}%")
    
    # --- Summary ---
    print(f"\n{'='*60}")
    print(f" SUMMARY")
    print(f"{'='*60}")
    print(f"  Uniformity:   {uniformity1:.2f}%  {'PASS' if 40 < uniformity1 < 60 else 'FAIL'} (target: 40-60%)")
    if reliability1 is not None:
        print(f"  Reliability:  {reliability1:.2f}%   {'PASS' if reliability1 < 5 else 'FAIL'} (target: < 5%)")
    if file2:
        print(f"  Uniqueness:   {uniqueness:.2f}%  {'PASS' if 40 < uniqueness < 60 else 'FAIL'} (target: 40-60%)")
        print(f"  Bit-Aliasing: {avg_alias:.2f}%  {'PASS' if 40 < avg_alias < 60 else 'FAIL'} (target: 40-60%)")

if __name__ == '__main__':
    main()
