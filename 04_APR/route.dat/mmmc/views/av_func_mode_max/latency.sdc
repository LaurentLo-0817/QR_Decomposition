set_clock_latency -source -early -max -rise  -0.722847 [get_ports {i_clk}] -clock i_clk 
set_clock_latency -source -early -max -fall  -0.761266 [get_ports {i_clk}] -clock i_clk 
set_clock_latency -source -late -max -rise  -0.722847 [get_ports {i_clk}] -clock i_clk 
set_clock_latency -source -late -max -fall  -0.761266 [get_ports {i_clk}] -clock i_clk 
