// ============================================================
// uart_tx.v
// Standard UART Transmitter
// Parameterized clock frequency and baud rate.
// ============================================================

`timescale 1ns/1ps

module uart_tx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    output reg        tx
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    
    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  data_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state   <= IDLE;
            tx      <= 1'b1;
            tx_busy <= 1'b0;
            clk_cnt <= 0;
            bit_idx <= 0;
            data_reg<= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_busy  <= 1'b1;
                        data_reg <= tx_data;
                        state    <= START;
                        clk_cnt  <= 0;
                    end
                end
                START: begin
                    tx <= 1'b0; // Start bit
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state   <= DATA;
                        bit_idx <= 0;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                DATA: begin
                    tx <= data_reg[bit_idx];
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                STOP: begin
                    tx <= 1'b1; // Stop bit
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state   <= IDLE;
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
