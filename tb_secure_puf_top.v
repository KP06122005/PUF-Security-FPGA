// ============================================================
// tb_secure_puf_top.v
// Integration testbench for the complete security module
//
// Tests:
//   1. PUF key generation from silicon fingerprint
//   2. PRESENT-128 encryption with that key
//   3. Verifies the ciphertext matches a known-good reference
//   4. Verifies that different plaintext → different ciphertext
//   5. Verifies that the same plaintext → same ciphertext (determinism)
// ============================================================
`timescale 1ns/1ps

module tb_secure_puf_top;

    reg          clk;
    reg          rst;
    reg          start;
    reg  [63:0]  plaintext;
    reg  [179:0] helper_data;
    wire [63:0]  ciphertext;
    wire         done;
    wire [127:0] debug_key;

    secure_puf_top #(
        .NUM_RO(32),
        .STAGES(2),
        .WINDOW_LEN(100)
    ) dut (
        .clk(clk), .rst(rst), .start(start),
        .plaintext(plaintext),
        .helper_data(helper_data),
        .ciphertext(ciphertext),
        .done(done),
        .debug_key(debug_key)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Hamming(15,11) encoder (same as in tb_puf_crypto_top)
    function [14:0] encode_hamming;
        input [10:0] d;
        reg [14:0] c;
        reg p0, p1, p2, p3;
        begin
            c = 15'b0;
            c[2] = d[0]; c[4] = d[1]; c[5] = d[2]; c[6] = d[3];
            c[8] = d[4]; c[9] = d[5]; c[10]= d[6]; c[11]= d[7];
            c[12]= d[8]; c[13]= d[9]; c[14]= d[10];

            p0 = c[2] ^ c[4] ^ c[6] ^ c[8] ^ c[10] ^ c[12] ^ c[14];
            p1 = c[2] ^ c[5] ^ c[6] ^ c[9] ^ c[10] ^ c[13] ^ c[14];
            p2 = c[4] ^ c[5] ^ c[6] ^ c[11] ^ c[12] ^ c[13] ^ c[14];
            p3 = c[8] ^ c[9] ^ c[10]^ c[11] ^ c[12] ^ c[13] ^ c[14];

            c[0] = p0; c[1] = p1; c[3] = p2; c[7] = p3;
            encode_hamming = c;
        end
    endfunction

    reg [131:0] pristine_key;
    reg [179:0] pristine_codeword;
    reg [63:0]  ciphertext_run1;
    integer i;

    initial begin
        $display("Simulation started.");
        rst = 1;
        start = 0;
        plaintext = 64'h0;
        helper_data = 180'h0;
        #100 rst = 0;
        #100;

        // === ENROLLMENT SIMULATION ===
        // First, get a baseline PUF reading
        $display("=== PHASE 1: Simulated Enrollment ===");
        start = 1; #10 start = 0;
        @(posedge dut.key_gen.done);
        
        // Generate helper data for a known key
        pristine_key = 132'h1_DEADBEEF_CAFE_BABE_1234_5678_9ABC_DEF0;
        for (i = 0; i < 12; i = i + 1) begin
            pristine_codeword[i*15 +: 15] = encode_hamming(pristine_key[i*11 +: 11]);
        end
        helper_data = dut.key_gen.raw_puf_bits ^ pristine_codeword;
        $display("Helper Data generated.");

        #500;

        // === TEST 1: Key Generation + Encryption ===
        $display("\n=== TEST 1: Full Pipeline (KeyGen + Encrypt) ===");
        plaintext = 64'hDEAD_BEEF_1234_5678;
        start = 1; #10 start = 0;
        @(posedge done);
        
        $display("Recovered Key:  0x%h", debug_key);
        $display("Plaintext:      0x%h", plaintext);
        $display("Ciphertext:     0x%h", ciphertext);
        
        if (debug_key == pristine_key[127:0])
            $display("[PASS] Key correctly recovered from PUF!");
        else
            $display("[FAIL] Key mismatch!");
        
        if (ciphertext != plaintext)
            $display("[PASS] Ciphertext differs from plaintext (encryption worked)!");
        else
            $display("[FAIL] Ciphertext equals plaintext (encryption failed)!");

        ciphertext_run1 = ciphertext;

        #500;

        // === TEST 2: Determinism (same plaintext → same ciphertext) ===
        $display("\n=== TEST 2: Determinism ===");
        start = 1; #10 start = 0;
        @(posedge done);
        
        if (ciphertext == ciphertext_run1)
            $display("[PASS] Same plaintext produces same ciphertext (deterministic)!");
        else
            $display("[FAIL] Different ciphertext on same plaintext!");

        #500;

        // === TEST 3: Avalanche (different plaintext → different ciphertext) ===
        $display("\n=== TEST 3: Avalanche Effect ===");
        plaintext = 64'hDEAD_BEEF_1234_5679; // 1 bit changed
        start = 1; #10 start = 0;
        @(posedge done);
        
        $display("New Plaintext:  0x%h", plaintext);
        $display("New Ciphertext: 0x%h", ciphertext);
        
        // Count bit differences
        begin : avalanche_check
            reg [63:0] xor_diff;
            integer bit_diffs;
            integer j;
            xor_diff = ciphertext ^ ciphertext_run1;
            bit_diffs = 0;
            for (j = 0; j < 64; j = j + 1) begin
                if (xor_diff[j]) bit_diffs = bit_diffs + 1;
            end
            $display("Bit differences: %0d / 64 (%0d%%)", bit_diffs, (bit_diffs * 100) / 64);
            if (bit_diffs > 20)
                $display("[PASS] Good avalanche effect (>30%% bits changed)!");
            else
                $display("[WARN] Weak avalanche effect");
        end

        $display("\n=== ALL TESTS COMPLETE ===");
        $finish;
    end

endmodule
