# Define primary clock
create_clock -name i_clk -period 2.0 [get_ports i_clk]

# Reset is synchronous and not timing-critical
set_false_path -from [get_ports i_rst]

# Ignore IO timing for now (datapath-only focus)
set_false_path -from [get_ports i_a*]
set_false_path -from [get_ports i_b*]
set_false_path -from [get_ports i_valid]

set_false_path -to   [get_ports o_val*]
set_false_path -to   [get_ports o_valid]
