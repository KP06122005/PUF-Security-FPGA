// ============================================================
// uart_rx.v
// Standard UART Receiver with 16x oversampling simulation
// Parameterized clock frequency and baud rate.
// ============================================================

`timescale 1ns/1ps

module uart_rx #(
    parameter CLK_FREQ = 100_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam DATA  = 3'd2;
    localparam STOP  = 3'd3;
    
    reg [2:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    
    // Double flop RX to prevent metastability
    reg rx_r1, rx_r2;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_r1 <= 1'b1;
            rx_r2 <= 1'b1;
        end else begin
            rx_r1 <= rx;
            rx_r2 <= rx_r1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            clk_cnt  <= 0;
            bit_idx  <= 0;
            rx_data  <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;
            case (state)
                IDLE: begin
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if (rx_r2 == 1'b0) begin // Detect start bit
                        state <= START;
                    end
                end
                START: begin
                    if (clk_cnt == (CLKS_PER_BIT-1)/2) begin
                        if (rx_r2 == 1'b0) begin
                            clk_cnt <= 0;
                            state   <= DATA;
                        end else begin
                            state   <= IDLE; // False start
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                DATA: begin
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        rx_data[bit_idx] <= rx_r2;
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
                    if (clk_cnt == CLKS_PER_BIT-1) begin
                        clk_cnt <= 0;
                        state   <= IDLE;
                        rx_valid <= 1'b1; // Valid byte
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
