import axi_vip_pkg::*;
import axi_slv_0_pkg::*;
import axi_mst_0_pkg::*;

module tb();

// DUT generics.
parameter ID_WIDTH 					= 1;
parameter DATA_WIDTH 				= 64;
parameter BURST_LENGTH				= 7;
parameter B_BURST_LENGTH				= 8;


/***********************************/
/* AXI Slave I/F for configuration */
/***********************************/

reg [9:0]           pmem_addr;
reg [63:0]          pmem_do;

reg  				s_axi_aclk		;
reg  				s_axi_aresetn	;

wire [7:0]			s_axi_awaddr	;
wire [2:0]			s_axi_awprot	;
wire  				s_axi_awvalid	;
wire  				s_axi_awready	;

wire [31:0] 		s_axi_wdata		;
wire [3:0]			s_axi_wstrb		;
wire  				s_axi_wvalid	;
wire  				s_axi_wready	;

wire [1:0]			s_axi_bresp		;
wire  				s_axi_bvalid	;
wire  				s_axi_bready	;

wire [7:0] 			s_axi_araddr	;
wire [2:0] 			s_axi_arprot	;
wire  				s_axi_arvalid	;
wire  				s_axi_arready	;

wire [31:0] 		s_axi_rdata		;
wire [1:0]			s_axi_rresp		;
wire  				s_axi_rvalid	;
wire  		        s_axi_rready	;

// Reset and Clock (m_axi, s_axis, m_axis).
reg 				aclk			;
reg 				aresetn			;

/***********************/
/* AXI Master for DDR4 */
/***********************/

// Write Address Channel.
wire	[ID_WIDTH-1:0]		m_axi_awid		;
wire	[31:0]				m_axi_awaddr	;
wire	[B_BURST_LENGTH-1:0]				m_axi_awlen		;
wire	[2:0]				m_axi_awsize	;
wire	[1:0]				m_axi_awburst	;
wire						m_axi_awlock	;
wire	[3:0]				m_axi_awcache	;
wire	[2:0]				m_axi_awprot	;
wire	[3:0]				m_axi_awregion	;
wire	[3:0]				m_axi_awqos		;
wire						m_axi_awvalid	;
wire						m_axi_awready	;

// Write Data Channel.
wire	[DATA_WIDTH-1:0]	m_axi_wdata		;
wire	[DATA_WIDTH/8-1:0]	m_axi_wstrb		;
wire						m_axi_wlast		;
wire						m_axi_wvalid	;
wire						m_axi_wready	;

// Write Response Channel.
wire	[ID_WIDTH-1:0]		m_axi_bid		;
wire	[1:0]				m_axi_bresp		;
wire						m_axi_bvalid	;
wire						m_axi_bready	;

// Read Address Channel.
wire	[ID_WIDTH-1:0]		m_axi_arid		;
wire	[31:0]				m_axi_araddr	;
wire	[B_BURST_LENGTH-1:0]				m_axi_arlen		;
wire	[2:0]				m_axi_arsize	;
wire	[1:0]				m_axi_arburst	;
wire						m_axi_arlock	;
wire	[3:0]				m_axi_arcache	;
wire	[2:0]				m_axi_arprot	;
wire	[3:0]				m_axi_arregion	;
wire	[3:0]				m_axi_arqos		;
wire						m_axi_arvalid	;
wire						m_axi_arready	;

// Read Data Channel.
wire	[ID_WIDTH-1:0]		m_axi_rid		;
wire	[DATA_WIDTH-1:0]	m_axi_rdata		;
wire	[1:0]				m_axi_rresp		;
wire						m_axi_rlast		;
wire						m_axi_rvalid	;
wire						m_axi_rready	;

/*************************/
/* AXIS Master Interfase */
/*************************/
wire						m_axis_tvalid	;
wire	[DATA_WIDTH-1:0]	m_axis_tdata	;
wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	;
wire						m_axis_tlast	;
reg							m_axis_tready	;

/************************/
/* AXIS Slave Interfase */
/************************/
wire						s_axis_tready	;
reg		[DATA_WIDTH-1:0]	s_axis_tdata	;
reg		[DATA_WIDTH/8-1:0]	s_axis_tstrb	;
reg							s_axis_tlast	;
reg							s_axis_tvalid	;

xil_axi_prot_t  prot        = 0;
xil_axi_resp_t  resp;
reg [31:0]       data;

// AXI Slave.
axi_slv_0 axi_slv_0_i
	(
		.aclk			(aclk			),
		.aresetn		(aresetn		),

		.s_axi_araddr	(m_axi_araddr	),
		.s_axi_arburst	(m_axi_arburst	),
		.s_axi_arcache	(m_axi_arcache	),
		.s_axi_arid		(m_axi_arid		),
		.s_axi_arlen	(m_axi_arlen	),
		.s_axi_arlock	(m_axi_arlock	),
		.s_axi_arprot	(m_axi_arprot	),
		.s_axi_arqos	(m_axi_arqos	),
		.s_axi_arready	(m_axi_arready	),
		.s_axi_arregion	(m_axi_arregion	),
		.s_axi_arsize	(m_axi_arsize	),
		.s_axi_arvalid	(m_axi_arvalid	),

		.s_axi_awaddr	(m_axi_awaddr	),
		.s_axi_awburst	(m_axi_awburst	),
		.s_axi_awcache	(m_axi_awcache	),
		.s_axi_awid		(m_axi_awid		),
		.s_axi_awlen	(m_axi_awlen	),
		.s_axi_awlock	(m_axi_awlock	),
		.s_axi_awprot	(m_axi_awprot	),
		.s_axi_awqos	(m_axi_awqos	),
		.s_axi_awready	(m_axi_awready	),
		.s_axi_awregion	(m_axi_awregion	),
		.s_axi_awsize	(m_axi_awsize	),
		.s_axi_awvalid	(m_axi_awvalid	),

		.s_axi_bid		(m_axi_bid		),
		.s_axi_bready	(m_axi_bready	),
		.s_axi_bresp	(m_axi_bresp	),
		.s_axi_bvalid	(m_axi_bvalid	),

		.s_axi_rdata	(m_axi_rdata	),
		.s_axi_rid		(m_axi_rid		),
		.s_axi_rlast	(m_axi_rlast	),
		.s_axi_rready	(m_axi_rready	),
		.s_axi_rresp	(m_axi_rresp	),
		.s_axi_rvalid	(m_axi_rvalid	),

		.s_axi_wdata	(m_axi_wdata	),
		.s_axi_wlast	(m_axi_wlast	),
		.s_axi_wready	(m_axi_wready	),
		.s_axi_wstrb	(m_axi_wstrb	),
		.s_axi_wvalid	(m_axi_wvalid	)
	);


// AXI Master.
axi_mst_0 axi_mst_0_i
	(
		.aclk			(s_axi_aclk		),
		.aresetn		(s_axi_aresetn	),
		.m_axi_araddr	(s_axi_araddr	),
		.m_axi_arprot	(s_axi_arprot	),
		.m_axi_arready	(s_axi_arready	),
		.m_axi_arvalid	(s_axi_arvalid	),
		.m_axi_awaddr	(s_axi_awaddr	),
		.m_axi_awprot	(s_axi_awprot	),
		.m_axi_awready	(s_axi_awready	),
		.m_axi_awvalid	(s_axi_awvalid	),
		.m_axi_bready	(s_axi_bready	),
		.m_axi_bresp	(s_axi_bresp	),
		.m_axi_bvalid	(s_axi_bvalid	),
		.m_axi_rdata	(s_axi_rdata	),
		.m_axi_rready	(s_axi_rready	),
		.m_axi_rresp	(s_axi_rresp	),
		.m_axi_rvalid	(s_axi_rvalid	),
		.m_axi_wdata	(s_axi_wdata	),
		.m_axi_wready	(s_axi_wready	),
		.m_axi_wstrb	(s_axi_wstrb	),
		.m_axi_wvalid	(s_axi_wvalid	)
	);



// DUT.
qt3_tpu_v1
	#(
		.ID_WIDTH				(ID_WIDTH				),
		.DATA_WIDTH				(DATA_WIDTH				),
        .BURST_LENGTH           (BURST_LENGTH           ),
        .B_BURST_LENGTH         (B_BURST_LENGTH)
	)
	DUT
	( 	
		// Trigger.

		/***********************************/
		/* AXI Slave I/F for configuration */
		/***********************************/

		.pmem_addr       ,
		.pmem_do         ,


		.s_axi_aclk		,
		.s_axi_aresetn	,

		.s_axi_awaddr	,
		.s_axi_awprot	,
		.s_axi_awvalid	,
		.s_axi_awready	,

		.s_axi_wdata	,
		.s_axi_wstrb	,
		.s_axi_wvalid	,
		.s_axi_wready	,

		.s_axi_bresp	,
		.s_axi_bvalid	,
		.s_axi_bready	,

		.s_axi_araddr	,
		.s_axi_arprot	,
		.s_axi_arvalid	,
		.s_axi_arready	,

		.s_axi_rdata	,
		.s_axi_rresp	,
		.s_axi_rvalid	,
		.s_axi_rready	,

		// Reset and Clock (m_axi, s_axis, m_axis).
		.aclk			,
		.aresetn		,

		/***********************/
		/* AXI Master for DDR4 */
		/***********************/

		// Write Address Channel.
		.m_axi_awid		,
		.m_axi_awaddr	,
		.m_axi_awlen	,
		.m_axi_awsize	,
		.m_axi_awburst	,
		.m_axi_awlock	,
		.m_axi_awcache	,
		.m_axi_awprot	,
		.m_axi_awregion	,
		.m_axi_awqos	,
		.m_axi_awvalid	,
		.m_axi_awready	,

		// Write Data Channel.
		.m_axi_wdata	,
		.m_axi_wstrb	,
		.m_axi_wlast	,
		.m_axi_wvalid	,
		.m_axi_wready	,

		// Write Response Channel.
		.m_axi_bid		,
		.m_axi_bresp	,
		.m_axi_bvalid	,
		.m_axi_bready	,

		// Read Address Channel.
		.m_axi_arid		,
		.m_axi_araddr	,
		.m_axi_arlen	,
		.m_axi_arsize	,
		.m_axi_arburst	,
		.m_axi_arlock	,
		.m_axi_arcache	,
		.m_axi_arprot	,
		.m_axi_arregion	,
		.m_axi_arqos	,
		.m_axi_arvalid	,
		.m_axi_arready	,

		// Read Data Channel.
		.m_axi_rid		,
		.m_axi_rdata	,
		.m_axi_rresp	,
		.m_axi_rlast	,
		.m_axi_rvalid	,
		.m_axi_rready	
	);


// VIP Agents
axi_slv_0_slv_mem_t axi_slv_0_agent;
axi_mst_0_mst_t 	axi_mst_0_agent;


// Main TB.
initial begin
	// Create agents.
	axi_slv_0_agent = new("axi_slv_0 VIP Agent",tb.axi_slv_0_i.inst.IF);
	axi_mst_0_agent	= new("axi_mst_0 VIP Agent",tb.axi_mst_0_i.inst.IF);

	// AXI Slave (memory model) beat gap.
	axi_slv_0_agent.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
	axi_slv_0_agent.mem_model.set_inter_beat_gap_range(10,20);

	// Set tag for agents.
	axi_slv_0_agent.set_agent_tag("axi_slv_0 VIP");
	axi_mst_0_agent.set_agent_tag("axi_mst_0 VIP");

	// Start agents.
	axi_slv_0_agent.start_slave();
	axi_mst_0_agent.start_master();

	// Reset sequence.
	s_axi_aresetn 	<= 0;
	aresetn 	    <= 0;
    
	#500;

	s_axi_aresetn 	<= 1;
	aresetn 	    <= 1;

	#1000;

	// DDR_BASEADDR_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*1, prot, 32'h40000000, resp);

	// START_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, 1, resp);

    #100;

	// START_REG.
	axi_mst_0_agent.AXI4LITE_WRITE_BURST(4*0, prot, 0, resp);
	
	#15000; // in ns.


	// read results.
	axi_mst_0_agent.AXI4LITE_READ_BURST(4*2, prot, data, resp);

    $display("partial sum: 0x%04X", data);


end








always begin
	s_axi_aclk <= 0;
	#7;
	s_axi_aclk <= 1;
	#7;
end



always begin
	aclk <= 0;
	#5;
	aclk <= 1;
	#5;
end  

endmodule

