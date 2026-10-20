// ============================================================
// ro_array_top.v
// Array of NUM_RO ring oscillators with per-oscillator counters
// and a pairwise challenge-response comparator.
//
// Protocol:
//   1. Host asserts sel_a / sel_b (which two RO indices to compare)
//   2. Host pulses `start`
//   3. FPGA counts edges of both selected... actually ALL oscillators
//      free-run and are counted continuously during the sampling
//      window (simpler and lets you log raw counts for debugging).
//   4. After the window, `response` = 1 if RO[sel_a] is faster
//      than RO[sel_b], and `done` pulses high.
//
// NOTE ON CLOCK DOMAINS: each counter is clocked directly by its
// own oscillator (~hundreds of MHz, uncontrolled frequency). This
// is standard for RO-PUFs but means count[] is read across a clock
// domain boundary in the COMPARE state. For a first working version
// this is acceptable (counts are static once `enable` drops), but
// for a hardened version add a synchronizer / only read count[]
// several clk cycles after enable is deasserted.
// ============================================================

module ro_array_top #(
    parameter integer NUM_RO    = 32,   // number of ring oscillators (start small, scale to 64 later)
    parameter integer STAGES    = 4,   // per-RO inverter stages (see ring_osc.v)
    parameter integer CNT_WIDTH = 32,  // width of each per-RO counter
    parameter integer WINDOW_LEN = 999_999 // sampling window length in clk cycles (~10ms @ 100MHz)
)(
    input  wire                          clk,     // system clock, e.g. 100 MHz
    input  wire                          rst,
    input  wire                          start,   // pulse to begin a sampling window
    input  wire [$clog2(NUM_RO)-1:0]     sel_a,   // challenge: RO index A
    input  wire [$clog2(NUM_RO)-1:0]     sel_b,   // challenge: RO index B
    output reg                           response,// 1 if RO[sel_a] faster than RO[sel_b]
    output reg                           done,
    output wire [NUM_RO*CNT_WIDTH-1:0]   raw_counts // flattened debug output of all counters
);

    wire [NUM_RO-1:0] osc_out;
    reg               ro_enable;

    // ---------------------------------------------------------
    // RO array instantiation
    // ---------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < NUM_RO; g = g + 1) begin : gen_ro
            ring_osc #(.STAGES(STAGES)) ro_inst (
                .enable  (ro_enable),
                .osc_out (osc_out[g])
            );
        end
    endgenerate

    // ---------------------------------------------------------
    // Per-RO counters, each clocked by its own oscillator
    // ---------------------------------------------------------
    reg [CNT_WIDTH-1:0] count [0:NUM_RO-1];
    reg                 clear_counters;
    wire                cnt_rst = rst | clear_counters;

    generate
        for (g = 0; g < NUM_RO; g = g + 1) begin : gen_cnt
            always @(posedge osc_out[g] or posedge cnt_rst) begin
                if (cnt_rst)
                    count[g] <= {CNT_WIDTH{1'b0}};
                else
                    count[g] <= count[g] + 1'b1;
            end

            assign raw_counts[(g+1)*CNT_WIDTH-1 -: CNT_WIDTH] = count[g];
        end
    endgenerate

    // ---------------------------------------------------------
    // Sampling window state machine (clk domain)
    // ---------------------------------------------------------
    localparam IDLE     = 3'd0;
    localparam CLEAR    = 3'd5;
    localparam SAMPLING = 3'd1;
    localparam SETTLE   = 3'd2;
    localparam COMPARE  = 3'd3;
    localparam DONE_ST  = 3'd4;

    reg [2:0]  state;
    reg [23:0] window_cnt;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state          <= IDLE;
            ro_enable      <= 1'b0;
            done           <= 1'b0;
            window_cnt     <= 24'd0;
            response       <= 1'b0;
            clear_counters <= 1'b0;
        end else begin
            clear_counters <= 1'b0;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        clear_counters <= 1'b1;
                        state          <= CLEAR;
                    end
                end

                CLEAR: begin
                    // Wait one cycle for counters to clear, then enable oscillators
                    ro_enable  <= 1'b1;
                    window_cnt <= 24'd0;
                    state      <= SAMPLING;
                end

                SAMPLING: begin
                    window_cnt <= window_cnt + 1'b1;
                    if (window_cnt >= WINDOW_LEN[23:0]) begin
                        ro_enable  <= 1'b0;   // stop all oscillators, counts hold
                        state      <= SETTLE;
                        window_cnt <= 24'd0;  // reuse window_cnt for settle delay
                    end
                end

                SETTLE: begin
                    window_cnt <= window_cnt + 1'b1;
                    // Wait 4 clock cycles for oscillators to fully stall and counters to settle
                    if (window_cnt >= 24'd3) begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // NOTE: this compares counts asynchronously latched from
                    // free-running RO clock domains -- see clock domain note above.
                    response <= (count[sel_a] > count[sel_b]) ? 1'b1 : 1'b0;
                    state    <= DONE_ST;
                end

                DONE_ST: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
