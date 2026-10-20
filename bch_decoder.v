// ============================================================
// bch_decoder.v
// A Hardware ECC Decoder for the PUF Fuzzy Extractor
// Implements a Hamming(15,11) decoder (a BCH code with d=3).
// Corrects 1 bit error per 15-bit block.
// ============================================================
`timescale 1ns/1ps

module bch_decoder (
    input  wire [14:0] noisy_codeword,
    output wire [10:0] corrected_message,
    output wire        error_detected
);

    wire [3:0] syndrome;
    wire [14:0] c = noisy_codeword;
    
    // Calculate syndrome bits (S = c * H^T)
    // 0-based index checks (corresponding to 1-based binary positions)
    assign syndrome[0] = c[0] ^ c[2] ^ c[4] ^ c[6] ^ c[8] ^ c[10] ^ c[12] ^ c[14];
    assign syndrome[1] = c[1] ^ c[2] ^ c[5] ^ c[6] ^ c[9] ^ c[10] ^ c[13] ^ c[14];
    assign syndrome[2] = c[3] ^ c[4] ^ c[5] ^ c[6] ^ c[11] ^ c[12] ^ c[13] ^ c[14];
    assign syndrome[3] = c[7] ^ c[8] ^ c[9] ^ c[10] ^ c[11] ^ c[12] ^ c[13] ^ c[14];

    // Decode error locator
    reg [14:0] error_vector;
    
    always @(*) begin
        error_vector = 15'b0;
        if (syndrome != 4'b0) begin
            // The syndrome value is the 1-based index of the error
            error_vector[syndrome - 1] = 1'b1;
        end
    end

    // Correct the codeword
    wire [14:0] corrected_codeword = c ^ error_vector;
    
    // Extract the 11-bit data message
    // Data bits are at 0-based indices: 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14
    assign corrected_message = {
        corrected_codeword[14], // D11
        corrected_codeword[13], // D10
        corrected_codeword[12], // D9
        corrected_codeword[11], // D8
        corrected_codeword[10], // D7
        corrected_codeword[9],  // D6
        corrected_codeword[8],  // D5
        corrected_codeword[6],  // D4
        corrected_codeword[5],  // D3
        corrected_codeword[4],  // D2
        corrected_codeword[2]   // D1
    };
    
    assign error_detected = (syndrome != 4'b0);

endmodule
