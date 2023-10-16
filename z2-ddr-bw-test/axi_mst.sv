

module axi_mst
	#(
		// Parameters of AXI Master I/F.
		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64			,
		parameter BURST_LENGTH				= 7,
		parameter  B_BURST_LENGTH            = 4   
	)
	(

		/**************/
		/* AXI Master */
		/**************/

		// Reset and Clock.
		input	wire						m_axi_aclk		,
		input	wire						m_axi_aresetn	,

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
		output	wire						m_axi_rready	,

		/*************************/
		/* AXIS Master Interfase */
		/*************************/
		output	wire						m_axis_tvalid	,
		output	wire	[DATA_WIDTH-1:0]	m_axis_tdata	,
		output	wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	,
		output	wire						m_axis_tlast	,
		input	wire						m_axis_tready	,

		/************************/
		/* AXIS Slave Interfase */
		/************************/
		output	wire						s_axis_tready	,
		input	wire	[DATA_WIDTH-1:0]	s_axis_tdata	,
		input	wire	[DATA_WIDTH/8-1:0]	s_axis_tstrb	,
		input	wire						s_axis_tlast	,
		input	wire						s_axis_tvalid	,

		// Registers.

		input	wire						RSTART_REG		,
		input	wire	[31:0]				RADDR_REG		,
		input	wire	[31:0]				RNBURST_REG		,
		output	wire                        RIDLE_REG  	,

		input	wire						WSTART_REG		,
		input	wire	[31:0]				WADDR_REG		,
		input	wire	[31:0]				WNBURST_REG,
        input	wire           				WIDLE_REG  	,		

		output wire [5 * 32 - 1:0] probe
	);

/*************/
/* Internals */
/*************/


/****************/
/* Architecture */
/****************/

// AXI Master Read.
axi_mst_read
    #(
		// Parameters of AXI Master I/F.
		
		.ID_WIDTH				(ID_WIDTH				),
		.DATA_WIDTH				(DATA_WIDTH				),
		.BURST_LENGTH			(BURST_LENGTH			),
		.B_BURST_LENGTH         (B_BURST_LENGTH)
    )
	axi_mst_read_i
    (
		.clk    		(m_axi_aclk		),
		.rstn 			(m_axi_aresetn	),

		// AXI Master Interface.
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

		.m_axi_rid		(m_axi_rid		),
		.m_axi_rdata	(m_axi_rdata	),
		.m_axi_rresp	(m_axi_rresp	),
		.m_axi_rlast	(m_axi_rlast	),
		.m_axi_rvalid	(m_axi_rvalid	),
		.m_axi_rready	(m_axi_rready	),

		// AXIS Master Interfase.
		.m_axis_tvalid	(m_axis_tvalid	),
		.m_axis_tdata	(m_axis_tdata	),
		.m_axis_tstrb	(m_axis_tstrb	),
		.m_axis_tlast	(m_axis_tlast	),
		.m_axis_tready	(m_axis_tready	),

		// Registers.
		.START_REG		(RSTART_REG		),
		.ADDR_REG		(RADDR_REG		),
		.NBURST_REG		(RNBURST_REG	),
		.IDLE_REG       (RIDLE_REG      ),

		.probe (probe)
    );


	

// AXI Master Write.
axi_mst_write
    #(
		.ID_WIDTH				(ID_WIDTH				),
		.DATA_WIDTH				(DATA_WIDTH				),
		.BURST_LENGTH			(0				),
		.B_BURST_LENGTH         (B_BURST_LENGTH)
    )
	axi_mst_write_i
    (
		.clk   			(m_axi_aclk		),
		.rstn 			(m_axi_aresetn	),

		// AXI Master Interface.
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

		.m_axi_wid      (m_axi_wid      ),
		.m_axi_wdata	(m_axi_wdata	),
		.m_axi_wstrb	(m_axi_wstrb	),
		.m_axi_wlast	(m_axi_wlast	),
		.m_axi_wvalid	(m_axi_wvalid	),
		.m_axi_wready	(m_axi_wready	),

		.m_axi_bid		(m_axi_bid		),
		.m_axi_bresp	(m_axi_bresp	),
		.m_axi_bvalid	(m_axi_bvalid	),
		.m_axi_bready	(m_axi_bready	),

		// AXIS Slave Interfase.
		.s_axis_tready	(s_axis_tready	),
		.s_axis_tdata	(s_axis_tdata	),
		.s_axis_tstrb	(s_axis_tstrb	),
		.s_axis_tlast	(s_axis_tlast	),
		.s_axis_tvalid	(s_axis_tvalid	),

		// Registers.
		.START_REG		(WSTART_REG		),
		.ADDR_REG		(WADDR_REG		),
		.NBURST_REG		(WNBURST_REG	),
		.IDLE_REG    	(WIDLE_REG	)		
    );

endmodule

