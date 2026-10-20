// ============================================================
// secure_puf_top.v
// Master Security Module
//
// Combines the PUF key generator with the PRESENT-128 cipher
// to create a complete hardware security module.
//
// On start:
//   1. PUF generates a 128-bit key from silicon fingerprint
//   2. PRESENT cipher encrypts the input plaintext with that key
//   3. Ciphertext is output — key never leaves the module
//
// The key exists ONLY in flip-flops and vanishes on power-off.
// ============================================================
`timescale 1ns/1ps

module secure_puf_top #(
    parameter NUM_RO     = 32,
    parameter STAGES     = 4,
    parameter WINDOW_LEN = 999_999
)(
    input  wire         clk,
    input  wire         rst,
    input  wire         start,          // Pulse to begin key gen + encryption
    input  wire [63:0]  plaintext,      // 64-bit data to encrypt
    input  wire [179:0] helper_data,    // Public helper data (from enrollment)
    output wire [63:0]  ciphertext,     // Encrypted output
    output reg          done,           // Pulses when ciphertext is ready
    output wire [127:0] debug_key       // Optional: expose key for verification (remove in production!)
);

    // ---------------------------------------------------------
    // Internal signals
    // ---------------------------------------------------------
    reg          puf_start;
    wire         puf_done;
    wire [127:0] puf_key;
    wire [11:0]  puf_errors;

    reg          cipher_start;
    wire         cipher_done;

    // ---------------------------------------------------------
    // Stage 1: PUF Key Generator (Fuzzy Extractor)
    // ---------------------------------------------------------
    puf_crypto_top #(
        .NUM_RO(NUM_RO),
        .STAGES(STAGES),
        .WINDOW_LEN(WINDOW_LEN)
    ) key_gen (
        .clk(clk),
        .rst(rst),
        .start(puf_start),
        .helper_data(helper_data),
        .done(puf_done),
        .aes_key(puf_key),
        .errors_detected(puf_errors)
    );

    // ---------------------------------------------------------
    // Stage 2: PRESENT-128 Cipher
    // ---------------------------------------------------------
    present_cipher cipher_inst (
        .clk(clk),
        .rst(rst),
        .start(cipher_start),
        .key(puf_key),
        .plaintext(plaintext),
        .ciphertext(ciphertext),
        .done(cipher_done)
    );

    assign debug_key = puf_key;

    // ---------------------------------------------------------
    // Master FSM: Key Gen → Encrypt
    // ---------------------------------------------------------
    localparam S_IDLE       = 2'd0;
    localparam S_KEYGEN     = 2'd1;
    localparam S_ENCRYPT    = 2'd2;

    reg [1:0] state;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            puf_start    <= 1'b0;
            cipher_start <= 1'b0;
            done         <= 1'b0;
        end else begin
            puf_start    <= 1'b0;
            cipher_start <= 1'b0;
            done         <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        puf_start <= 1'b1;
                        state     <= S_KEYGEN;
                    end
                end

                S_KEYGEN: begin
                    if (puf_done) begin
                        cipher_start <= 1'b1;
                        state        <= S_ENCRYPT;
                    end
                end

                S_ENCRYPT: begin
                    if (cipher_done) begin
                        done  <= 1'b1;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
