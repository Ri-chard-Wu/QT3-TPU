

module qt3_tpu_v1
	#(
		parameter PMEM_N		            = 32             ,
		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64			,

		parameter BURST_LENGTH				= 15				, 
		
		parameter  B_BURST_LENGTH            = 4,
		
		parameter B_PIXEL = 16, 
		parameter B_INST = 32 ,

		parameter N_KERNEL = 3,
		parameter N_CONV_UNIT = 64,
		parameter FW    = 253,
		parameter UNIT_BURSTS = 2048

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




wire [B_PIXEL-1:0] partial_sum_i [0:N_CONV_UNIT-1];
wire [B_PIXEL-1:0] partial_sum_o [0:N_CONV_UNIT-1];
wire [B_INST-1:0]  inst_i        [0:N_CONV_UNIT-1];
wire [B_INST-1:0]  inst_o        [0:N_CONV_UNIT-1];


wire   [N_CONV_UNIT-1:0]  wb_we     				;
wire   [N_CONV_UNIT-1:0]  wb_clr    				;
wire   [N_CONV_UNIT-1:0]  wb_empty  				;
wire   [N_KERNEL-1:0]     kb_we    [0:N_CONV_UNIT-1];
wire   [N_KERNEL-1:0]     kb_clr   [0:N_CONV_UNIT-1];
wire   [N_CONV_UNIT-1:0]  kb_empty 					;
wire [DATA_WIDTH-1:0]     di        			    ;


reg [3:0] cu_sel_r;
reg [3:0] cu_sel_wei;
reg [3:0] cu_sel_ker;

wire [3:0] cu_sel_i;



wire          fifo_wr_en_i;
wire [FW-1:0] fifo_din_i;
wire 		  fifo_ready_i;


localparam	INIT_ST		       = 0;
localparam	LOAD_WEIGHT_ST     = 1;
localparam	LOAD_KERNEL_ST     = 2;

reg			init_state;
reg			load_wei_state;
reg			load_kernel_state;

reg [3:0] state;





ctrl #(
		.PMEM_N  (PMEM_N         ),
		.FW      (FW)
	)
	ctrl_i
	(
		.clk		    (aclk			),
		.rstn         	(aresetn		),

		.pmem_addr      (pmem_addr      ),
		.pmem_do        (pmem_do        ),

		.START_REG      (START_REG      ),

		.start          (start          ),

        .fifo_wr_en     (fifo_wr_en_i),
        .fifo_din       (fifo_din_i  ),
		.fifo_ready     (fifo_ready_i)
	);


// assign fifo_din = 	{  opcode_i   ,
//                         page_i     ,
//                         oper_i     ,
// 						   reg_dout6_i,
// 						   reg_dout5_i,
// 						   reg_dout4_i,
// 						   reg_dout3_i,
// 						   reg_dout2_i,
//                         reg_dout1_i,
// 						   reg_dout0_i	
//                     };



always @( posedge aclk )
begin
    if ( aresetn == 1'b0 ) begin
		
		state	   <= INIT_ST;

		cu_sel_r   <= 0;
		cu_sel_wei <= 0;
		cu_sel_ker <= 0;	
    end 
    else begin    

		case(state)

			INIT_ST:
                if (fifo_wr_en_i == 0)
                    state <= INIT_WEI_ST;
			
			LATCH_ST:
				state <= LOAD_WEI_ST;


			// load wei until sufficient -> load fm until done -> load wei until done -> pre-load next layer.
			LOAD_WEI_ST:
				if (wb_sufficient_i && ~fb_done_i)  // done loading all wei, but not all fm.
					state <= LOAD_FM_ST;
				else if(wb_done_i)
					state <= INIT_ST;
					
			LOAD_FM_ST:
				if (fb_done_i)
					state <= LOAD_WEI_ST;
		endcase	



		if (latch_state == 1'b1) begin
			wei_addr_r          <= wei_addr;
			wei_n_rema_bursts_r <= wei_n_rema_bursts;
			wei_n_bursts_r		<= wei_n_bursts_next;
			
			cu_sel_wei <= 0;
		end
		else if (load_wei_state == 1'b1) begin
			wei_addr_r          <= wei_addr_r + wei_n_bursts_r;
			wei_n_rema_bursts_r <= wei_n_rema_bursts_r - wei_n_bursts_r;
			wei_n_bursts_r      <= wei_n_bursts_next;

			cu_sel_wei <= cu_sel_wei_next;
		end

    end
end    


assign wei_n_bursts_next = (UNIT_BURSTS > wei_n_rema_bursts) ? wei_n_rema_bursts : UNIT_BURSTS;
assign cu_sel_wei_next = (mem_we == 1'b1) ? cu_sel_wei + 1 : cu_sel_wei;



assign wei_addr 		 = fifo_din_i[31:0];
assign wei_n_last_burst  = fifo_din_i[38:32];
assign wei_n_rema_bursts = fifo_din_i[51:39];
// assign wei_n        	= fifo_din_i[63:52];

assign fm_addr 	  	 	= fifo_din_i[95:64];
assign fm_n_last_burst  = fifo_din_i[102:96];
assign fm_n_bursts 		= fifo_din_i[127:103];

assign wei_shape        = fifo_din_i[159:128];
assign fm_shape         = fifo_din_i[191:160];
assign out_addr         = fifo_din_i[223:192];

assign RSTART_REG  = load_wei_state | load_fm_state;	 
assign RADDR_REG   = (load_wei_state) ? wei_addr_r :
					 (load_fm_state)  ? fm_addr_r : 0;
assign RNBURST_REG = (load_wei_state) ? wei_n_bursts_r :
				     (load_fm_state)  ? fm_n_bursts : 0; 



// FSM outputs.
always @(state) begin

    init_state	        = 0;
	load_wei_state   = 0;

	case (state)

		INIT_ST:
			init_state       	= 1;

		LOAD_WEIGHT_ST
			load_wei_state   = 1;
	endcase
end

assign fifo_ready_i = init_state;

assign cu_sel_i = (load_mode == 0) ? cu_sel_wei : cu_sel_ker;






ddr_buffer_reader
    #(
        .DATA_WIDTH  (DATA_WIDTH),
		.N_CONV_UNIT (N_CONV_UNIT)
    )
    ddr_buffer_reader_i
	( 
        .clk    		(aclk			),
		.rstn			(aresetn		),

		// AXIS Slave.
		.s_axis_tdata	(m_axis_tdata  ),
		.s_axis_tvalid	(m_axis_tvalid ),
		.s_axis_tready	(m_axis_tready ),

		// Output data.
        .mem_we         (mem_we         ),
        .mem_di         (di             )
    );


// wb_empty, kb_empty
// wb_clr, kb_clr


generate
genvar i;
	for (i=0; i < N_CONV_UNIT; i=i+1) begin : GEN_CONV_UNIT


        assign partial_sum_i[i] = (i==0) ? 0 : partial_sum_o_arr[i-1];
        assign inst_i[i] = (i==0) ? conv_inst : inst_o[i-1];

		// Each with 4 groups of 3-DSP, 5 36kb-BRAM as weight buffer,  3 36kb-BRAM as kernel buffer.
		// Each perform 12 muls per cycle.
		// We need 16 such unit along channel dir.
		conv_unit #(
				.DATA_WIDTH(DATA_WIDTH),
				.N_KERNEL  (N_KERNEL)
			)
			conv_unit_i
			(
				.clk		    (aclk			),
				.rstn         	(aresetn		),

				input wire [B_LAYERPARA-1:0]   layer_para    ,
				input wire                     layer_para_we ,

				.wb_we          (wb_we[i]       ),
				.wb_clr         (wb_clr[i]      ),
				.wb_empty       (wb_empty[i]    ),
				.kb_we          (kb_we[i]       ),
				.kb_clr         (kb_clr[i]      ),
				.kb_empty       (kb_empty[i]    ),
				.di             (di             ),


				.partial_sum_i  (partial_sum_i[i]),
				.partial_sum_o  (partial_sum_o[i]),
				.inst_i			(inst_i[i]		  ),
				.inst_o			(inst_o[i]		  ),
			);
		
		assign en[i]    = (cu_sel_i == i) ? 1 : 0;
		assign wb_we[i] = en[i] & ((load_mode == 0) ? mem_we : 0);
		assign kb_we[i] = en[i] & ((load_mode == 1) ? mem_we : 0);
		
	end
endgenerate 




activation_unit #(

	)
	activation_unit_i
	(
		.clk		    (aclk			             ),
		.rstn         	(aresetn					 ),

		.inst           (act_inst                    ),
		.di             (partial_sum_o[N_CONV_UNIT-1]),
		.do				()
	);



// data_writer
//     #(
//         .DATA_WIDTH  (DATA_WIDTH),
// 		.N_CONV_UNIT (N_CONV_UNIT)
//     )
//     data_writer_i
// 	( 
//         .clk    		(aclk			),
// 		.rstn			(aresetn			),

// 		// AXIS Slave.
// 		.s_axis_tdata	(m_axis_tdata  ),
// 		.s_axis_tvalid	(m_axis_tvalid ),
// 		.s_axis_tready	(m_axis_tready ),

// 		// Output data.
//         // .mem_we         (mem_we         ),

// 		.wb_we          (wb_we      ),
// 		.wb_clr         (wb_clr     ),
// 		.wb_empty       (wb_empty   ),
// 		.kb_we          (kb_we      ),
// 		.kb_clr         (kb_clr     ),
// 		.kb_empty       (kb_empty   ),
//         .mem_di         (di         )
//     );






// unified_buffer #(

// 	)
// 	unified_buffer_i
// 	(
// 		.clk		    (aclk			),
// 		.rstn         	(aresetn		),

		
// 	);


// pool_unit #(

// 	)
// 	pool_unit_i
// 	(
// 		.clk		    (aclk			),
// 		.rstn         	(aresetn		),

		
// 	);


// // has state machine.
// // has 40 36kb-BRAM.
// accumulator #(

// 	)
// 	accumulator_i
// 	(
// 		.clk		    (aclk			),
// 		.rstn         	(aresetn		),

		
// 	);



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

