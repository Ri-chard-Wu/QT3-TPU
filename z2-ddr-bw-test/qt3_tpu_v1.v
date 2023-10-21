

module qt3_tpu_v1
	#(
		parameter PMEM_N		            = 32             ,
		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64			,

		// max can go up to 15? test it.
		parameter BURST_LENGTH				= 15				, 

		// z2 only support 4, but in simulation we must use 8.
		parameter  B_BURST_LENGTH            = 4             
	)
	( 	

		output	wire [PMEM_N-1:0]	        pmem_addr       ,   
		input	wire [63:0]			        pmem_do         ,



			
		`define x(name_iterface, name_item) \
			(* X_INTERFACE_INFO = `"xilinx.com:interface:aximm:1.0 name_iterface name_item `" *)
	
	
		(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
		(* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET s_axi_aresetn, FREQ_HZ 100000000" *)
		input   wire                   s_axi_aclk,
		
		(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0  s_axi_aresetn  RST" *)
		(* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
		input   wire                   s_axi_aresetn,

		`x(s_axi, AWADDR)  	input 	wire	[7:0]				s_axi_awaddr	,
		`x(s_axi, AWPROT)   input 	wire 	[2:0]				s_axi_awprot	,
		`x(s_axi, AWVALID) 	input 	wire  						s_axi_awvalid	,
		`x(s_axi, AWREADY) 	output	wire  						s_axi_awready	,
		`x(s_axi, WDATA) 	input 	wire 	[31:0] 				s_axi_wdata		,
		`x(s_axi, WSTRB) 	input 	wire 	[3:0]				s_axi_wstrb		,
		`x(s_axi, WVALID) 	input 	wire  						s_axi_wvalid	,
		`x(s_axi, WREADY) 	output 	wire  						s_axi_wready	,
		`x(s_axi, BRESP) 	output 	wire 	[1:0]				s_axi_bresp		,
		`x(s_axi, BVALID) 	output 	wire  						s_axi_bvalid	,
		`x(s_axi, BREADY) 	input 	wire  						s_axi_bready	,
		`x(s_axi, ARADDR) 	input 	wire 	[7:0] 				s_axi_araddr	,
		`x(s_axi, ARPROT) 	input 	wire 	[2:0] 				s_axi_arprot	,
		`x(s_axi, ARVALID) 	input 	wire  						s_axi_arvalid	,
		`x(s_axi, ARREADY) 	output 	wire  						s_axi_arready	,
		`x(s_axi, RDATA) 	output 	wire 	[31:0] 				s_axi_rdata		,
		`x(s_axi, RRESP) 	output 	wire 	[1:0]				s_axi_rresp		,
		`x(s_axi, RVALID) 	output 	wire  						s_axi_rvalid	,
		`x(s_axi, RREADY) 	input 	wire  						s_axi_rready	,




		// Reset and Clock (m_axi, s_axis, m_axis).
		input	wire						aclk			,
		input	wire						aresetn			,

		/***********************/
		/* AXI-Full Master for DDR4 */
		/***********************/

		// Write Address Channel.
		output	wire	[ID_WIDTH-1:0]		m_axi_awid		,
		output	wire	[31:0]				m_axi_awaddr	,
		output	wire	[B_BURST_LENGTH - 1:0]				m_axi_awlen		,
		output	wire	[2:0]				m_axi_awsize	,
		output	wire	[1:0]				m_axi_awburst	,
		output	wire	[1:0]				m_axi_awlock	,
		output	wire	[3:0]				m_axi_awcache	,
		output	wire	[2:0]				m_axi_awprot	,
		output	wire	[3:0]				m_axi_awqos		,
		output	wire						m_axi_awvalid	,
		input	wire						m_axi_awready	,

		// Write Data Channel.
		output	wire	[ID_WIDTH-1:0]		m_axi_wid		,
		output	wire	[DATA_WIDTH-1:0]	m_axi_wdata		,
		output	wire	[DATA_WIDTH/8-1:0]	m_axi_wstrb		,
		output	wire						m_axi_wlast		,
		output	wire						m_axi_wvalid	,
		input	wire						m_axi_wready	,

		// Write Response Channel.
		input	wire	[ID_WIDTH-1:0]		m_axi_bid		,
		input	wire	[1:0]				m_axi_bresp		,
		input	wire						m_axi_bvalid	,
		output	wire						m_axi_bready	,

		// Read Address Channel.
		output	wire	[ID_WIDTH-1:0]		m_axi_arid		,
		output	wire	[31:0]				m_axi_araddr	,
		output	wire	[B_BURST_LENGTH - 1:0]				m_axi_arlen		,
		output	wire	[2:0]				m_axi_arsize	,
		output	wire	[1:0]				m_axi_arburst	,
		output	wire	[1:0]				m_axi_arlock	,
		output	wire	[3:0]				m_axi_arcache	,
		output	wire	[2:0]				m_axi_arprot	,
		output	wire	[3:0]				m_axi_arqos		,
		output	wire						m_axi_arvalid	,
		input	wire						m_axi_arready	,

		// Read Data Channel.
		input	wire	[ID_WIDTH-1:0]		m_axi_rid		,
		input	wire	[DATA_WIDTH-1:0]	m_axi_rdata		,
		input	wire	[1:0]				m_axi_rresp		,
		input	wire						m_axi_rlast		,
		input	wire						m_axi_rvalid	,
		output	wire						m_axi_rready	

		
	);
	




/*************************/
/* AXIS Master Interfase */
/*************************/
wire						m_axis_tvalid	;
wire	[DATA_WIDTH-1:0]	m_axis_tdata	;
wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	;
wire						m_axis_tlast	;
wire						m_axis_tready	;

/************************/
/* AXIS Slave Interfase */
/************************/
wire						s_axis_tready	;
wire	[DATA_WIDTH-1:0]	s_axis_tdata	;
wire	[DATA_WIDTH/8-1:0]	s_axis_tstrb	;
wire						s_axis_tlast	;
wire						s_axis_tvalid   ;
	
/********************/
/* Internal signals */
/********************/

// Registers.
wire            START_REG;

wire			RSTART_REG	;
wire	[31:0]	RADDR_REG	;
wire	[31:0]	RNBURST_REG	;
wire            RIDLE_REG   ;

wire			WSTART_REG	;
wire	[31:0]	WADDR_REG	;
wire	[31:0]	WNBURST_REG	;
wire	     	WIDLE_REG	;



wire        start;
wire [31:0] partial_sum;


wire [2 * 32 - 1:0] stimulus;
wire [5 * 32 - 1:0] probe;

/**********************/
/* Begin Architecture */
/**********************/
// AXI Slave.
axi_slv axi_slv_i
	(
		.s_axi_aclk		(s_axi_aclk	  	),
		.s_axi_aresetn	(s_axi_aresetn	),

		// Write Address Channel.
		.s_axi_awaddr	(s_axi_awaddr	),
		.s_axi_awprot	(s_axi_awprot	),
		.s_axi_awvalid	(s_axi_awvalid	),
		.s_axi_awready	(s_axi_awready	),

		// Write Data Channel.
		.s_axi_wdata	(s_axi_wdata	),
		.s_axi_wstrb	(s_axi_wstrb	),
		.s_axi_wvalid	(s_axi_wvalid	),
		.s_axi_wready	(s_axi_wready	),

		// Write Response Channel.
		.s_axi_bresp	(s_axi_bresp	),
		.s_axi_bvalid	(s_axi_bvalid	),
		.s_axi_bready	(s_axi_bready	),

		// Read Address Channel.
		.s_axi_araddr	(s_axi_araddr	),
		.s_axi_arprot	(s_axi_arprot	),
		.s_axi_arvalid	(s_axi_arvalid	),
		.s_axi_arready	(s_axi_arready	),

		// Read Data Channel.
		.s_axi_rdata	(s_axi_rdata	),
		.s_axi_rresp	(s_axi_rresp	),
		.s_axi_rvalid	(s_axi_rvalid	),
		.s_axi_rready	(s_axi_rready	),

		// Registers.
		.START_REG        (START_REG       )
		
	);


// assign pmem_addr = stimulus[PMEM_N-1:0]; // reg3
// assign probe[2 * 32 +: 32] = pmem_do[63:32]; // reg7
// assign probe[4 * 32 +: 32] = pmem_do[31:0];  // reg9

ctrl #(
		.PMEM_N         (PMEM_N         )
	)
	ctrl_i
	(
		.clk		    (aclk			),
		.rstn         	(aresetn		),

		.pmem_addr      (pmem_addr        ),
		.pmem_do        (pmem_do          ),

		.START_REG      (START_REG),

		.RSTART_REG		(RSTART_REG		),
		.RADDR_REG		(RADDR_REG		),
		.RNBURST_REG	(RNBURST_REG	),
		.RIDLE_REG      (RIDLE_REG      ),

		.WSTART_REG		(WSTART_REG		),
		.WADDR_REG		(WADDR_REG		),
		.WNBURST_REG	(WNBURST_REG	),
		.WIDLE_REG      (WIDLE_REG      ),

		.start          (start          )

		// .probe (probe)
	);




localparam N_MAC = 1;
wire [DATA_WIDTH-1 : 0] 	mem_di;
wire                        mem_we;

data_writer
    #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    data_writer_i
	( 
        .clk    		(aclk			),
		.rstn			(aresetn			),

		// AXIS Slave.
		.s_axis_tdata	(m_axis_tdata  ),
		.s_axis_tvalid	(m_axis_tvalid ),
		.s_axis_tready	(m_axis_tready ),

		// Output data.
        .mem_we         (mem_we         ),
        .mem_di         (mem_di         )
    );


wire [16*(N_MAC + 2)-1:0] wei_i;
reg [16*(N_MAC + 2)-1:0] wei;
reg [16*(N_MAC + 2)-1:0] fm;
wire [15:0] res[0:N_MAC-1];
reg [8:0] addr_b_r;

// reg [16*N_MAC-1:0]       res_r;
// reg [DATA_WIDTH-1:0] data_r;
// reg [31:0] cnt_r;
// wire [31:0] mux_sel;


always @( posedge aclk )
begin
    if ( aresetn == 1'b0 ) begin
        wei  <= 48'hfff1_0038_006E; // 110, 56, -15
        fm <= 48'h0100_ffd2_ff9c; // -100, -46, 256
		addr_b_r <= 0;
		// data_r <= 0;
		// cnt_r <= 0;
    end 
    else begin    

        if (mem_we) begin   
			addr_b_r <= addr_b_r + 1;	
        end

        // if (mem_we) begin   
		// 	wei[16*(N_MAC + 2)-1:16] <= wei[16*(N_MAC + 1)-1:0];
        //     wei[15:0] <= mem_di;

		// 	fm[16*(N_MAC + 2)-1:16] <= wei[16*(N_MAC + 1)-1:0] + fm[16*(N_MAC + 1)-1:0];
        //     fm[15:0] <= mem_di;			
        // end 		
		
		// cnt_r <= cnt_r + 1;
    end
end    



generate
genvar i;
	for (i=0; i < N_MAC; i=i+1) begin : GEN_i

		mac_v2 
			#(
				.N_MUL(3)
			)
			mac_v2_i
			(
				.clk 		(aclk),
				.rstn		(aresetn),

				.wei        (wei_i[16*i+:16*3]),
				.fm         (fm[16*i+:16*3]),

				.WSTART_REG (WSTART_REG),
				.RSTART_REG (RSTART_REG),

				.res (res[i])
			);


	end
endgenerate 

wire [63:0] DO;

// assign wei_i = {DO[15:0], wei_i[16+:32]};
assign wei_i = DO[47:0];

// assign mux_sel = cnt_r;
assign s_axis_tvalid = 1'b1;
assign s_axis_tdata = res[0];






BRAM_SDP_MACRO #(
	.BRAM_SIZE("36Kb"), // Target BRAM, "18Kb" or "36Kb" 
	.DEVICE("7SERIES"), // Target device: "7SERIES" 
	.WRITE_WIDTH(64),    // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
	.READ_WIDTH(64),     // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
	.DO_REG(0),         // Optional output register (0 or 1)
	.INIT_FILE ("NONE"),
	.SIM_COLLISION_CHECK ("ALL"),   // Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE" 
	.SRVAL(72'h000000000000000000), // Set/Reset value for port output
	.INIT(72'h000000000000000000),  // Initial values on output port
	.WRITE_MODE("READ_FIRST")   // Specify "READ_FIRST" for same clock or synchronous clocks
									// Specify "WRITE_FIRST for asynchronous clocks on ports
) BRAM_SDP_MACRO_inst (

	.DO(DO),         // Output read data port, width defined by READ_WIDTH parameter
	.RDADDR(9'b000000001), // Input read address, width defined by read port depth
	.RDCLK(aclk),   // 1-bit input read clock
	.RDEN(1'b1),     // 1-bit input read port enable
	
	.REGCE(1'b0),   // 1-bit input read output register enable
	.RST(~aresetn),       // 1-bit input reset
	.WE(8'b11111111),         // Input write enable, width defined by write port depth

	// .DI({{48{1'b0}}, mem_di[0+:16]}),         
	.DI(mem_di[0+:16]),         

	.WRADDR(addr_b_r), // Input write address, width defined by write port depth
	.WRCLK(aclk),   // 1-bit input write clock
	.WREN(mem_we)      // 1-bit input write port enable
);






// generate
// genvar i;
// 	for (i=0; i < N_MAC; i=i+1) begin : GEN_i

// 		bram_dp 
// 			#(
// 				.N(5),
// 				.B(64)
// 			)
// 			bram_dp_i
// 			(
			
// 				.clka    (aclk)
// 				.clkb    (aclk)
// 				.ena     (1'b1)
// 				.enb     (1'b1)
// 				.wea     (1'b1)
// 				.web     (1'b0)
// 				.addra   (5'b00000)
// 				.addrb   ()
// 				.dia     (res[16*i+:16])
// 				.dib     ()
// 				.doa     ()
// 				.dob     ()
// 			);
// 	end
// endgenerate 



axi_mst
	#(
		// Parameters of AXI Master I/F.
		
		.ID_WIDTH				(ID_WIDTH				),
		.DATA_WIDTH				(DATA_WIDTH				),
		.BURST_LENGTH			(BURST_LENGTH		    ),
		.B_BURST_LENGTH (B_BURST_LENGTH)
	)
	axi_mst_i
	(
	
		/**************/
		/* AXI Master */
		/**************/

		// Reset and Clock.
		.m_axi_aclk		(aclk			),
		.m_axi_aresetn	(aresetn		),

		// Write Address Channel.
		.m_axi_awid		(m_axi_awid		),
		.m_axi_awaddr	(m_axi_awaddr	),
		.m_axi_awlen	(m_axi_awlen	),
		.m_axi_awsize	(m_axi_awsize	),
		.m_axi_awburst	(m_axi_awburst	),
		.m_axi_awlock	(m_axi_awlock	),
		.m_axi_awcache	(m_axi_awcache	),
		.m_axi_awprot	(m_axi_awprot	),
		.m_axi_awqos	(m_axi_awqos	),
		.m_axi_awvalid	(m_axi_awvalid	),
		.m_axi_awready	(m_axi_awready	),

		// Write Data Channel.
		.m_axi_wid      (m_axi_wid      ),
		.m_axi_wdata	(m_axi_wdata	),
		.m_axi_wstrb	(m_axi_wstrb	),
		.m_axi_wlast	(m_axi_wlast	),
		.m_axi_wvalid	(m_axi_wvalid	),
		.m_axi_wready	(m_axi_wready	),

		// Write Response Channel.
		.m_axi_bid		(m_axi_bid		),
		.m_axi_bresp	(m_axi_bresp	),
		.m_axi_bvalid	(m_axi_bvalid	),
		.m_axi_bready	(m_axi_bready	),

		// Read Address Channel.
		.m_axi_arid		(m_axi_arid		),
		.m_axi_araddr	(m_axi_araddr	),
		.m_axi_arlen	(m_axi_arlen	),
		.m_axi_arsize	(m_axi_arsize	),
		.m_axi_arburst	(m_axi_arburst	),
		.m_axi_arlock	(m_axi_arlock	),
		.m_axi_arcache	(m_axi_arcache	),
		.m_axi_arprot	(m_axi_arprot	),
		.m_axi_arqos	(m_axi_arqos	),
		.m_axi_arvalid	(m_axi_arvalid	),
		.m_axi_arready	(m_axi_arready	),

		// Read Data Channel.
		.m_axi_rid		(m_axi_rid		),
		.m_axi_rdata	(m_axi_rdata	),
		.m_axi_rresp	(m_axi_rresp	),
		.m_axi_rlast	(m_axi_rlast	),
		.m_axi_rvalid	(m_axi_rvalid	),
		.m_axi_rready	(m_axi_rready	),

		/*************************/
		/* AXIS Master Interfase */
		/*************************/
		// from axi_mst_read.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tstrb	(m_axis_tstrb	),
		.m_axis_tlast	(m_axis_tlast	),
		.m_axis_tready	(m_axis_tready	),

		/************************/
		/* AXIS Slave Interfase */
		/************************/
		// from axi_mst_write.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tdata	(s_axis_tdata	),
		.s_axis_tstrb	(s_axis_tstrb	),
		.s_axis_tlast	(s_axis_tlast	),
		.s_axis_tvalid	(s_axis_tvalid	),

		// Registers.
		.RSTART_REG		(RSTART_REG		),
		.RADDR_REG		(RADDR_REG		),
		.RNBURST_REG	(RNBURST_REG	),
		.RIDLE_REG      (RIDLE_REG      ),

		.WSTART_REG		(WSTART_REG		),
		.WADDR_REG		(WADDR_REG		),
		.WNBURST_REG	(WNBURST_REG	),
		.WIDLE_REG  	(WIDLE_REG	)
		

		// .probe (probe)
	);




endmodule

