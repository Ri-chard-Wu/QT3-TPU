

set clk_axi [get_clocks -of_objects [get_nets -of_objects [get_pins design_1_i/processing_system7_0/FCLK_CLK0]]]
set clk_wiz_0  [get_clocks -of_objects [get_nets -of_objects [get_pins design_1_i/clk_wiz_0/clk_out1]]]


set_clock_group -name clk_axi_to_clk_wiz_0 -asynchronous \
    -group [get_clocks $clk_axi] \
    -group [get_clocks $clk_wiz_0]
