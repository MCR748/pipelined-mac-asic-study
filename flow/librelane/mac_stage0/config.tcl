# Design name
set ::env(DESIGN_NAME) mac_top

# RTL sources (single authoritative copy)
set ::env(VERILOG_FILES) "\
    $::env(DESIGN_DIR)/../../../rtl/mac/mac_pkg.sv \
    $::env(DESIGN_DIR)/../../../rtl/mac/mac_top.sv \
"

# Clock
set ::env(CLOCK_PORT) clk
set ::env(CLOCK_PERIOD) 2.0
