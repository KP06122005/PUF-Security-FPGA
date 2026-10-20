// ============================================================
// present_cipher.v
// PRESENT-128 Lightweight Block Cipher (ISO/IEC 29192-2)
//
// - 64-bit block size, 128-bit key
// - 31 rounds of substitution-permutation
// - Iterative architecture: 1 round per clock cycle
// - Extremely compact: ~1500 gate equivalents
// ============================================================
`timescale 1ns/1ps

module present_cipher (
    input  wire         clk,
    input  wire         rst,
    input  wire         start,
    input  wire [127:0] key,
    input  wire [63:0]  plaintext,
    output reg  [63:0]  ciphertext,
    output reg          done
);

    // PRESENT S-Box (4-bit substitution)
    function [3:0] sbox;
        input [3:0] x;
        case (x)
            4'h0: sbox = 4'hC;  4'h1: sbox = 4'h5;
            4'h2: sbox = 4'h6;  4'h3: sbox = 4'hB;
            4'h4: sbox = 4'h9;  4'h5: sbox = 4'h0;
            4'h6: sbox = 4'hA;  4'h7: sbox = 4'hD;
            4'h8: sbox = 4'h3;  4'h9: sbox = 4'hE;
            4'hA: sbox = 4'hF;  4'hB: sbox = 4'h8;
            4'hC: sbox = 4'h4;  4'hD: sbox = 4'h7;
            4'hE: sbox = 4'h1;  4'hF: sbox = 4'h2;
        endcase
    endfunction

    // PRESENT P-Layer (64-bit permutation)
    function [63:0] player;
        input [63:0] s;
        integer i;
        reg [63:0] p;
        begin
            p = 64'b0;
            for (i = 0; i < 63; i = i + 1) begin
                // P(i) = (i * 16) mod 63
                p[(i * 16) % 63] = s[i];
            end
            p[63] = s[63];
            player = p;
        end
    endfunction

    // Apply S-box to all 16 nibbles of a 64-bit state
    function [63:0] sbox_layer;
        input [63:0] s;
        integer i;
        reg [63:0] result;
        begin
            for (i = 0; i < 16; i = i + 1) begin
                result[i*4 +: 4] = sbox(s[i*4 +: 4]);
            end
            sbox_layer = result;
        end
    endfunction

    // State
    reg [63:0]  state;
    reg [127:0] key_reg;
    reg [4:0]   round_cnt;  // 1 to 31
    reg [1:0]   fsm;

    localparam FSM_IDLE   = 2'd0;
    localparam FSM_ROUND  = 2'd1;
    localparam FSM_FINAL  = 2'd2;

    // Key schedule wires
    wire [63:0]  round_key = key_reg[127:64]; // Top 64 bits
    wire [127:0] key_rotated = {key_reg[66:0], key_reg[127:67]}; // Rotate left by 61
    wire [127:0] key_after_sbox = {
        sbox(key_rotated[127:124]),
        sbox(key_rotated[123:120]),
        key_rotated[119:0]
    };
    wire [127:0] key_after_xor = {
        key_after_sbox[127:67],
        key_after_sbox[66:62] ^ round_cnt,
        key_after_sbox[61:0]
    };

    // Round computation wires
    wire [63:0] after_add_key = state ^ round_key;
    wire [63:0] after_sbox    = sbox_layer(after_add_key);
    wire [63:0] after_player  = player(after_sbox);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            fsm        <= FSM_IDLE;
            done       <= 1'b0;
            ciphertext <= 64'b0;
            state      <= 64'b0;
            key_reg    <= 128'b0;
            round_cnt  <= 5'd1;
        end else begin
            done <= 1'b0;
            
            case (fsm)
                FSM_IDLE: begin
                    if (start) begin
                        state     <= plaintext;
                        key_reg   <= key;
                        round_cnt <= 5'd1;
                        fsm       <= FSM_ROUND;
                    end
                end

                FSM_ROUND: begin
                    // Apply one round: addRoundKey -> sBoxLayer -> pLayer
                    state   <= after_player;
                    // Update key schedule
                    key_reg <= key_after_xor;
                    
                    if (round_cnt == 5'd31) begin
                        fsm <= FSM_FINAL;
                    end
                    round_cnt <= round_cnt + 1'b1;
                end

                FSM_FINAL: begin
                    // Final addRoundKey (no S-box or P-layer)
                    ciphertext <= state ^ round_key;
                    done       <= 1'b1;
                    fsm        <= FSM_IDLE;
                end

                default: fsm <= FSM_IDLE;
            endcase
        end
    end

endmodule
