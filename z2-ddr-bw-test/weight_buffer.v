
module weight_buffer
	#(
		parameter B_ADDR = 9,
		parameter B_DATA = 64
	)
	( 	
        input wire          	clk     ,    
        input wire          	rstn    ,  	

		input wire [B_ADDR-1:0]	rdaddr  ,
		input wire [B_DATA-1:0]	di      ,

		input wire 			    we      ,
		input wire [B_ADDR-1:0]	wraddr  ,
		input wire [B_DATA-1:0]	do      		
	);
	



BRAM_SDP_MACRO #(
	.BRAM_SIZE("36Kb"), // Target BRAM, "18Kb" or "36Kb" 
	.DEVICE("7SERIES"), // Target device: "7SERIES" 
	.WRITE_WIDTH(B_DATA),    // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
	.READ_WIDTH(B_DATA),     // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
	.DO_REG(0),         // Optional output register (0 or 1)
	.INIT_FILE ("NONE"),
	.SIM_COLLISION_CHECK ("ALL"),   // Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE" 
	.SRVAL(72'h000000000000000000), // Set/Reset value for port output
	.INIT(72'h000000000000000000),  // Initial values on output port
	.WRITE_MODE("READ_FIRST")   // Specify "READ_FIRST" for same clock or synchronous clocks
									// Specify "WRITE_FIRST for asynchronous clocks on ports
) BRAM_SDP_MACRO_inst (

	.DO(do),         // Output read data port, width defined by READ_WIDTH parameter
	.RDADDR(rdaddr), // Input read address, width defined by read port depth
	.RDCLK(clk),   // 1-bit input read clock
	.RDEN(1'b1),     // 1-bit input read port enable
	
	.REGCE(1'b0),      // 1-bit input read output register enable
	.RST(~rstn),       // 1-bit input reset
	.WE(8'b11111111),         // Input write enable, width defined by write port depth

	.DI(di),         
    

	.WRADDR(wraddr), // Input write address, width defined by write port depth
	.WRCLK(clk),   // 1-bit input write clock
	.WREN(we)      // 1-bit input write port enable
);







endmodule

