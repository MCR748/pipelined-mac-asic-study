# Define primary clock
create_clock -name clk -period 2.0 [get_ports clk]

# Reset is synchronous and not timing-critical
set_false_path -from [get_ports rst]

# Ignore IO timing for now (datapath-only focus)
set_false_path -from [get_ports input_a*]
set_false_path -from [get_ports input_b*]
set_false_path -from [get_ports input_valid]

set_false_path -to   [get_ports output_val*]
set_false_path -to   [get_ports output_valid]
