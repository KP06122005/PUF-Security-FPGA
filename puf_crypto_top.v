// ============================================================
// puf_crypto_top.v
// Top-level Hardware Fuzzy Extractor
// Sweeps 180 PUF challenges, extracts bits, applies Helper Data,
// and decodes a pristine 128-bit key.
// ============================================================
`timescale 1ns/1ps

module puf_crypto_top #(
    parameter CLK_FREQ = 100_000_000,
    parameter NUM_RO = 32,
    parameter STAGES = 4,
    parameter WINDOW_LEN = 999_999
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [179:0] helper_data, // 12 blocks of 15 bits
    output reg          done,
    output reg  [127:0] aes_key,
    output wire [11:0]  errors_detected
);

    // ---------------------------------------------------------
    // PUF Array Interface
    // ---------------------------------------------------------
    reg  puf_start;
    wire [$clog2(NUM_RO)-1:0] sel_a, sel_b;
    wire puf_response;
    wire puf_done;
    
    wire [NUM_RO*32-1:0] dummy_raw_counts;

    ro_array_top #(
        .NUM_RO(NUM_RO), .STAGES(STAGES), .CNT_WIDTH(32), .WINDOW_LEN(WINDOW_LEN)
    ) puf_array (
        .clk(clk), .rst(rst), .start(puf_start),
        .sel_a(sel_a), .sel_b(sel_b),
        .response(puf_response), .done(puf_done), .raw_counts(dummy_raw_counts)
    );

    // ---------------------------------------------------------
    // Challenge Generator (180 unique pairs)
    // ---------------------------------------------------------
    reg [7:0] challenge_idx; // 0 to 179
    
    reg [$clog2(NUM_RO)-1:0] current_sel_a;
    reg [3:0] mod_12_cnt;

    assign sel_a = current_sel_a;
    assign sel_b = current_sel_a + 1 + mod_12_cnt;

    // ---------------------------------------------------------
    // FSM
    // ---------------------------------------------------------
    localparam S_IDLE     = 3'd0;
    localparam S_TRIGGER  = 3'd1;
    localparam S_WAIT     = 3'd2;
    localparam S_DECODE   = 3'd3;

    reg [2:0] state;
    reg [179:0] raw_puf_bits;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            puf_start <= 1'b0;
            done <= 1'b0;
            aes_key <= 128'b0;
            challenge_idx <= 8'd0;
            current_sel_a <= 0;
            mod_12_cnt <= 0;
            raw_puf_bits <= 180'b0;
        end else begin
            puf_start <= 1'b0;
            done <= 1'b0;
            
            case (state)
                S_IDLE: begin
                    challenge_idx <= 8'd0;
                    current_sel_a <= 0;
                    mod_12_cnt <= 0;
                    if (start) begin
                        state <= S_TRIGGER;
                    end
                end
                
                S_TRIGGER: begin
                    puf_start <= 1'b1;
                    state <= S_WAIT;
                end
                
                S_WAIT: begin
                    if (puf_done) begin
                        raw_puf_bits[challenge_idx] <= puf_response;
                        
                        if (challenge_idx == 179) begin
                            state <= S_DECODE; 
                        end else begin
                            challenge_idx <= challenge_idx + 1'b1;
                            if (mod_12_cnt == 4'd11) begin
                                mod_12_cnt <= 0;
                                current_sel_a <= current_sel_a + 1'b1;
                            end else begin
                                mod_12_cnt <= mod_12_cnt + 1'b1;
                            end
                            state <= S_TRIGGER;
                        end
                    end
                end
                
                S_DECODE: begin
                    aes_key <= decoded_key_wire;
                    done <= 1'b1;
                    state <= S_IDLE;
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

    // ---------------------------------------------------------
    // BCH / Hamming Decoders
    // ---------------------------------------------------------
    wire [179:0] noisy_codeword_full = raw_puf_bits ^ helper_data;
    
    wire [131:0] full_corrected_message;
    // We only need 128 bits for the AES key, so we truncate the top 4 bits.
    wire [127:0] decoded_key_wire = full_corrected_message[127:0]; 
    
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : gen_bch
            bch_decoder decoder_inst (
                .noisy_codeword(noisy_codeword_full[i*15 +: 15]),
                .corrected_message(full_corrected_message[i*11 +: 11]),
                .error_detected(errors_detected[i])
            );
        end
    endgenerate

endmodule
