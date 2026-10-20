# ============================================================
# ro_puf_constraints.tcl
#
# Co-Located Differential Pair Placement for Nexys A7-100T
#
# Strategy: Place each RO PAIR (even RO + odd RO) inside the
# SAME slice so that systematic effects (temperature, voltage,
# routing) cancel out perfectly. Only random process variation
# (Vth mismatch) determines the comparison result.
#
# 16 pairs are scattered across the XC7A100T die to avoid
# spatial correlation between pairs.
#
# HOW TO ADD THIS FILE TO YOUR PROJECT:
#   - Add as a constraint file in Vivado
#   - Right-click it -> Source Node Properties
#   - UNCHECK "Used in Synthesis"
#   - CHECK   "Used in Implementation"
# ============================================================

set NUM_RO    32   ;# must match ro_array_top's NUM_RO parameter
set STAGES    4    ;# must match ro_array_top's STAGES parameter
set NUM_PAIRS 16   ;# NUM_RO / 2

# ------------------------------------------------------------
# 1. Combinational loop DRC bypass
# ------------------------------------------------------------
set_property SEVERITY {Warning} [get_drc_checks LUTLP-1]
set_property IS_ENABLED FALSE  [get_drc_checks LUTLP-1]

# ------------------------------------------------------------
# 2. Allow combinational loops on ALL RO chain nets
# ------------------------------------------------------------
set chain_nets [get_nets -hierarchical -filter {NAME =~ *ro_inst*chain*} -quiet]
if {[llength $chain_nets] > 0} {
    set_property ALLOW_COMBINATORIAL_LOOPS TRUE $chain_nets
    puts "Applied ALLOW_COMBINATORIAL_LOOPS to [llength $chain_nets] nets."
} else {
    puts "WARNING: No chain nets found. Skipping ALLOW_COMBINATORIAL_LOOPS."
}

# ------------------------------------------------------------
# 3. Co-located differential pair placement
# ------------------------------------------------------------
# Each pair gets ONE slice for the NAND gates and the slice
# above for the inverter stages. RO_A uses A6LUT/B6LUT BELs,
# RO_B uses C6LUT/D6LUT BELs within the same slice.
#
# Pair coordinates scattered across the XC7A100T die:
#   - Avoid columns 0-1 (I/O bank routing)
#   - Avoid very high columns (near right I/O bank)
#   - Spread across different clock regions for max diversity

# pair_locs: {col row} for each of the 16 pairs
set pair_locs {
    {10  5}
    {30  20}
    {50  35}
    {10  50}
    {30  65}
    {50  80}
    {10  95}
    {30  110}
    {50  5}
    {70  20}
    {70  35}
    {70  50}
    {70  65}
    {70  80}
    {70  95}
    {70  110}
}

for {set p 0} {$p < $NUM_PAIRS} {incr p} {

    set pair_coord [lindex $pair_locs $p]
    set col [lindex $pair_coord 0]
    set base_row [lindex $pair_coord 1]

    # RO indices for this pair
    set ro_a [expr {$p * 2}]
    set ro_b [expr {$p * 2 + 1}]

    # --- Place NAND gates of BOTH ROs in the SAME slice ---
    # RO_A NAND -> A6LUT,  RO_B NAND -> C6LUT  (same SLICE)
    set nand_a [get_cells -hierarchical -filter "NAME =~ *gen_ro\[$ro_a\].ro_inst/nand_inst" -quiet]
    set nand_b [get_cells -hierarchical -filter "NAME =~ *gen_ro\[$ro_b\].ro_inst/nand_inst" -quiet]

    if {[llength $nand_a] > 0} {
        set_property BEL "A6LUT" $nand_a
        set_property LOC "SLICE_X${col}Y${base_row}" $nand_a
    } else {
        puts "WARNING: Could not find NAND cell for RO $ro_a (pair $p)"
    }

    if {[llength $nand_b] > 0} {
        set_property BEL "C6LUT" $nand_b
        set_property LOC "SLICE_X${col}Y${base_row}" $nand_b
    } else {
        puts "WARNING: Could not find NAND cell for RO $ro_b (pair $p)"
    }

    # --- Place inverter stages ---
    # RO_A inverters use A6LUT/B6LUT, RO_B inverters use C6LUT/D6LUT
    # Both in the same slice(s) above the NAND slice
    for {set i 0} {$i < $STAGES} {incr i} {
        set row [expr {$base_row + ($i / 2) + 1}]

        # RO_A: alternate A6LUT and B6LUT
        set bel_a [expr {($i % 2) == 0 ? "A6LUT" : "B6LUT"}]
        # RO_B: alternate C6LUT and D6LUT
        set bel_b [expr {($i % 2) == 0 ? "C6LUT" : "D6LUT"}]

        set inv_a [get_cells -hierarchical -filter "NAME =~ *gen_ro\[$ro_a\].ro_inst/gen_lut\[$i\].inv_inst" -quiet]
        set inv_b [get_cells -hierarchical -filter "NAME =~ *gen_ro\[$ro_b\].ro_inst/gen_lut\[$i\].inv_inst" -quiet]

        if {[llength $inv_a] > 0} {
            set_property BEL $bel_a $inv_a
            set_property LOC "SLICE_X${col}Y${row}" $inv_a
        } else {
            puts "WARNING: Could not find inverter $i for RO $ro_a (pair $p)"
        }

        if {[llength $inv_b] > 0} {
            set_property BEL $bel_b $inv_b
            set_property LOC "SLICE_X${col}Y${row}" $inv_b
        } else {
            puts "WARNING: Could not find inverter $i for RO $ro_b (pair $p)"
        }
    }

    puts "Pair $p: RO$ro_a (A/B LUTs) + RO$ro_b (C/D LUTs) co-located at SLICE_X${col}Y${base_row}"
}

puts "Differential pair placement applied to $NUM_PAIRS pairs ($NUM_RO ROs total)."
