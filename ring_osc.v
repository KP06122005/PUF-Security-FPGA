// ============================================================
// ring_osc.v
// Single ring oscillator built from explicit LUT primitives.
//
// Structure: 1 NAND-gated LUT2 (enable gating) + STAGES inverting
// LUT1 stages. Total inversions = STAGES + 1, which MUST be odd
// for the ring to oscillate. Default STAGES=4 -> 5 total inversions.
//
// When enable=0, the NAND output is forced high (stable), stopping
// oscillation and preventing wasted power / noise between samples.
// ============================================================

module ring_osc #(
    parameter integer STAGES = 4   // number of inverter stages AFTER the NAND gate; keep even so STAGES+1 is odd
)(
    input  wire enable,
    output wire osc_out
);

    (* DONT_TOUCH = "TRUE" *) wire [STAGES:0] chain;

    // Stage 0: NAND gate used for enable gating.
    // Truth table for O = ~(I0 & I1): INIT = 4'b0111
    //   I1 I0 | O
    //    0  0 | 1
    //    0  1 | 1
    //    1  0 | 1
    //    1  1 | 0
    LUT2 #(.INIT(4'b0111)) nand_inst (
        .O  (chain[0]),
        .I0 (enable),
        .I1 (chain[STAGES])
    );

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : gen_lut
            // Simple inverter: O = ~I0, INIT = 2'b01
            LUT1 #(.INIT(2'b01)) inv_inst (
                .O  (chain[i+1]),
                .I0 (chain[i])
            );
        end
    endgenerate

    assign osc_out = chain[STAGES];

endmodule
