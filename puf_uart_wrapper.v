// ============================================================
// puf_uart_wrapper.v
// Top-level module for Phase 3
// Integrates UART Rx, UART Tx, and the PUF array.
// ============================================================

`timescale 1ns/1ps

module puf_uart_wrapper #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200,
    parameter NUM_RO = 8,
    parameter STAGES = 4,
    parameter CNT_WIDTH = 32,
    parameter WINDOW_LEN = 999_999
)(
    input  wire clk,
    input  wire rst,
    input  wire rx,
    output wire tx
);

    wire [7:0] rx_data;
    wire       rx_valid;
    
    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;

    // Instantiate UART Receiver
    uart_rx #(
        .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)
    ) urx (
        .clk(clk), .rst(rst), .rx(rx), 
        .rx_data(rx_data), .rx_valid(rx_valid)
    );

    // Instantiate UART Transmitter
    uart_tx #(
        .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)
    ) utx (
        .clk(clk), .rst(rst), .tx_data(tx_data), .tx_start(tx_start),
        .tx_busy(tx_busy), .tx(tx)
    );

    // PUF interface signals
    reg  start_puf;
    reg  [$clog2(NUM_RO)-1:0] sel_a, sel_b;
    wire puf_response;
    wire puf_done;
    wire [NUM_RO*CNT_WIDTH-1:0] raw_counts;

    // Instantiate PUF Array
    ro_array_top #(
        .NUM_RO(NUM_RO), .STAGES(STAGES), .CNT_WIDTH(CNT_WIDTH), .WINDOW_LEN(WINDOW_LEN)
    ) puf_array (
        .clk(clk), .rst(rst), .start(start_puf),
        .sel_a(sel_a), .sel_b(sel_b),
        .response(puf_response), .done(puf_done), .raw_counts(raw_counts)
    );

    localparam S_WAIT_SELA  = 4'd0;
    localparam S_WAIT_SELB  = 4'd1;
    localparam S_WAIT_PUF   = 4'd2;
    localparam S_TX_RESP    = 4'd3;
    localparam S_TX_RAW     = 4'd4;

    reg [3:0] state;
    reg [7:0] tx_byte_idx; 
    
    reg puf_response_latched;
    reg [NUM_RO*CNT_WIDTH-1:0] raw_counts_latched;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_WAIT_SELA;
            start_puf <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 0;
            sel_a <= 0;
            sel_b <= 0;
            tx_byte_idx <= 0;
            puf_response_latched <= 0;
            raw_counts_latched <= 0;
        end else begin
            start_puf <= 1'b0;
            tx_start  <= 1'b0;
            case (state)
                S_WAIT_SELA: begin
                    if (rx_valid) begin
                        sel_a <= rx_data[$clog2(NUM_RO)-1:0];
                        state <= S_WAIT_SELB;
                    end
                end
                S_WAIT_SELB: begin
                    if (rx_valid) begin
                        sel_b <= rx_data[$clog2(NUM_RO)-1:0];
                        start_puf <= 1'b1;
                        state <= S_WAIT_PUF;
                    end
                end
                S_WAIT_PUF: begin
                    if (puf_done) begin
                        puf_response_latched <= puf_response;
                        raw_counts_latched   <= raw_counts;
                        state <= S_TX_RESP;
                    end
                end
                S_TX_RESP: begin
                    if (!tx_busy) begin
                        tx_data  <= {7'd0, puf_response_latched};
                        tx_start <= 1'b1;
                        tx_byte_idx <= 0;
                        state    <= S_TX_RAW;
                    end
                end
                S_TX_RAW: begin
                    // Wait for tx to not be busy AND tx_start to be deasserted
                    if (!tx_busy && !tx_start) begin
                        if (tx_byte_idx < (NUM_RO*CNT_WIDTH/8)) begin
                            // Serialize array: LSB first
                            tx_data <= raw_counts_latched[(tx_byte_idx*8) +: 8];
                            tx_start <= 1'b1;
                            tx_byte_idx <= tx_byte_idx + 1'b1;
                        end else begin
                            state <= S_WAIT_SELA; // Ready for next challenge
                        end
                    end
                end
                default: state <= S_WAIT_SELA;
            endcase
        end
    end
endmodule
