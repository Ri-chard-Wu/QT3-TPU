

module qt3_tpu_v1
	#(
		parameter PMEM_N		            = 32             ,
		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64			,

		parameter BURST_LENGTH				= 15				, 
		
		parameter  B_BURST_LENGTH            = 4,
		
		parameter B_PIXEL = 16, 
		parameter B_INST = 32 ,

		parameter N_KERNEL = 4,
		parameter N_CONV_UNIT = 8,
		parameter FW    = 242,

		// The largest kernel [3, 3, 512] == 72 bursts (3*3*512*2 / 128).
		// A ftm that can just fill entire fb (2621.44 kb) == 2560 bursts.
		parameter UNIT_BURSTS_WEI = 32,  // need to be power of 2.
		parameter UNIT_BURSTS_FTM = 1024,  // need to be power of 2.
		parameter N_DSP_GROUP = 4

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
	wire								s_axis_tready	;
	wire	[DATA_WIDTH+ADDR_WIDTH-1:0]	s_axis_tdata	;
	wire	[DATA_WIDTH/8-1:0]			s_axis_tstrb	;
	wire								s_axis_tlast	;
	wire								s_axis_tvalid   ;
		
	/********************/
	/* Internal signals */
	/********************/

	// Registers.
	wire            START_REG;

	wire			RSTART_REG	;
	wire	[31:0]	RADDR_REG	;
	wire	[31:0]	RNBURST_REG	;
	wire            RDONE_REG   ;

	wire			WSTART_REG	;
	wire	[31:0]	WADDR_REG	;
	wire	[31:0]	WNBURST_REG	;
	wire	     	WIDLE_REG	;


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

	localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH / 8; // 8 bytes.
	localparam BYTES_PER_BURST			= (BURST_LENGTH + 1) * BYTES_PER_AXI_TRANSFER; // 16 * 8 = 128 bytes.


	wire   [N_CONV_UNIT-1:0] wb_we    ;
	wire   [N_CONV_UNIT-1:0] wb_clr   ;
	wire   [N_CONV_UNIT-1:0] wb_empty ;
	wire   [31:0]		     wb_cfg   ;
	wire   [N_CONV_UNIT-1:0] fb_we    ;
	wire   [N_CONV_UNIT-1:0] fb_clr   ;
	wire   [N_CONV_UNIT-1:0] fb_empty ;
	wire   [31:0]		     fb_cfg   ;
	wire   [DATA_WIDTH-1:0]  mem_di   ;

	wire   [N_CONV_UNIT-1:0] wb_suff       ;
	wire   [N_CONV_UNIT-1:0] wb_suff_reduc ;
	wire   [N_CONV_UNIT-1:0] wb_full       ;           
	wire   [N_CONV_UNIT-1:0] fb_suff       ; 
	wire   [N_CONV_UNIT-1:0] fb_full       ;         
	wire 				     wb_suff_i ;
	wire 				     wb_full_i ;   
	wire 				     wb_empty_i;	           
	wire 				     fb_suff_i ; 
	wire 				     fb_full_i ;    
	wire 				     fb_empty_i;  	     




	wire [FW-1:0]  	cfg_i_data  ;
	wire           	cfg_i_valid ;
	wire 		    cfg_i_ready ;

	wire [127:0] 	       m0_cfg_data ;
	wire 		           m0_cfg_valid;
	wire 				   m0_cfg_ready;
	// wire [N_CONV_UNIT-1:0] cfg_o_ready_i;

	// wire [63:0]   conv_para   ;
	// wire 		  conv_para_we;

	wire [31:0]   out_shape   ;
	wire [31:0]   out_addr    ;


	// pipe_en == 0 when
		// - ddr write fifo full.
		// - wb or fb want to access data that have not been read in from ddr.
	wire          		          pipe_en  ; 
	wire [N_CONV_UNIT-1:0]        pipe_en_i;
	wire [N_CONV_UNIT-1:0]        pipe_en_o;

	wire [2*B_PIXEL*N_KERNEL-1:0] acc_i [0:N_CONV_UNIT-1];
	wire [2*B_PIXEL*N_KERNEL-1:0] acc_o [0:N_CONV_UNIT-1];
	wire [N_CONV_UNIT-1:0] 	      acc_o_valid;

	wire [2:0] 				      act_func;
	wire [N_KERNEL*B_PIXEL:0]     act_do;
	wire 					      act_do_vaild;



	wire 		fifo_ftm_full ;
	wire 		fifo_ftm_wr_en;
	wire [63:0] fifo_ftm_di	  ;
	
	wire 		fifo_ftm_empty;
	wire 		fifo_ftm_rd_en;
	wire [63:0] fifo_ftm_dout ;
	
	


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

			.fifo_full  	(fifo_ftm_full  ),
			.fifo_wr_en	    (fifo_ftm_wr_en ),
			.fifo_di	    (fifo_ftm_di    ),

			.cfg_valid      (cfg_i_valid     ),
			.cfg_data       (cfg_i_data      ),
			.cfg_ready      (cfg_i_ready     )
		);



	// handle multiple input feature maps (e.g. concat).
	fifo
		#(
			// Data width.
			.B	(64	),
			
			// Fifo depth.
			.N	(16	)
		)
		fifo_ftm_i
		( 
			.clk	(aclk		),
			.rstn 	(aresetn	),
	
			.full   (fifo_ftm_full  ),
			.wr_en 	(fifo_ftm_wr_en	),
			.din    (fifo_ftm_di	),

			.empty  (fifo_ftm_empty	),
			.rd_en  (fifo_ftm_rd_en	),
			.dout   (fifo_ftm_dout	)
		);


	ddr_reader
		#(
			.N_KERNEL(N_KERNEL),
			.B_PIXEL (B_PIXEL),
			.DATA_WIDTH (DATA_WIDTH),
			.BURST_LENGTH (BURST_LENGTH),
			.N_DSP_GROUP (N_DSP_GROUP),
 						
		)
		ddr_reader_i
		( 
			.clk    		(aclk			),
			.rstn			(aresetn		),

			// cfg from ctrl.
			.cfg_i_valid     (cfg_i_valid     ),
			.cfg_i_data      (cfg_i_data      ),
			.cfg_i_ready     (cfg_i_ready     ),

			.cfg_o_data      (m0_cfg_data       ),
			.cfg_o_valid     (m0_cfg_valid      ),
			.cfg_o_ready     (m0_cfg_ready      ),

			.fifo_empty    (fifo_ftm_empty  ),
			.fifo_rd_en    (fifo_ftm_rd_en  ),
			.fifo_dout     (fifo_ftm_dout   ),
			
			// ddr controls.
			.RSTART_REG     (RSTART_REG  	),
			.RADDR_REG      (RADDR_REG   	),
			.RNBURST_REG    (RNBURST_REG 	),
			.RDONE_REG		(RDONE_REG   	),

			// ddr input.
			.m_axis_tvalid  (m_axis_tvalid  ),
			.m_axis_tdata   (m_axis_tdata   ),
			.m_axis_tready  (m_axis_tready  ),

			// write buffers.
			.wb_we    	    (wb_we    		),
			.wb_clr   	    (wb_clr   		),
			.wb_suff 	    (wb_suff_i      ),
			.wb_full        (wb_full_i      ),	
			.wb_cfg         (wb_cfg		    ),		
			.fb_we    	    (fb_we    		),
			.fb_clr   	    (fb_clr   		),
			.fb_suff 		(               ), // not needed?
			.fb_full        (fb_full_i      ),
			.fb_cfg         (fb_cfg		    ),			
			.mem_di 		(mem_di         )
		);





    cfg_prop
        #(
            .B    (128),             
        )
        cfg_prop_0_i
        (
            .clk  (clk	)	     ,    
            .rstn (rstn)         ,     

			.s_cfg_data  (m0_cfg_data  ), // 128-bits
			.s_cfg_valid (m0_cfg_valid ),
			.s_cfg_ready (m0_cfg_ready ),

			.m_cfg_done	 (m1_cfg_done  ),
			.m_cfg_run	 (m1_cfg_run   ),
			.m_cfg_data  (m1_cfg_data  ), // 128-bits
			.m_cfg_valid (m1_cfg_valid ),
			.m_cfg_ready (m1_cfg_ready )
        );

	generate
	genvar i;
		for (i=0; i < N_CONV_UNIT; i=i+1) begin : GEN_CONV_UNIT

			// Each with 4 groups of 4-DSP, 10 36kb-BRAM as weight buffer,  4 36kb-BRAM as kernel buffer.
			// Each perform 16 muls per cycle.
			// We need 8 such unit along channel dir.
			conv_unit #(
					.DATA_WIDTH(DATA_WIDTH),
					.N_KERNEL  (N_KERNEL),
					.N_CONV_UNIT(N_CONV_UNIT),
					.ID (4*i)
				)
				conv_unit_i
				(
					// Together with c1 can allow the conv to know whether it is the last one
						// in case c1 < N_CONV_UNIT * N_CONV_UNIT.	
					.is_tail		(is_tail[i]		), 

					.clk		    (aclk			),
					.rstn         	(aresetn		),

					.pipe_en    	(pipe_en       ),
					.pipe_en_i  	(pipe_en_i[i]  ),
					.pipe_en_o  	(pipe_en_o[i]  ),

					.cfg_wr_data    (m0_cfg_data[63:0]), 
					.cfg_rd_data    (m1_cfg_data     ),
					.cfg_rd_done	(m1_cfg_done_i[i] 	)
					.cfg_rd_run 	(m1_cfg_run     )

					// TODO: implement clr logic to clear regs in 
						// all conv_unit to be ready for next layer.
					.wb_we          (wb_we[i]         ),
					// .wb_clr         (wb_clr[i]        ),
					// .wb_empty       (wb_empty[i]      ),
					.wb_suff 		(wb_suff[i]  	  ),
					.wb_full        (wb_full[i] 	  ),

					.fb_we          (fb_we[i]         ),
					// .fb_clr         (fb_clr[i]        ),
					// .fb_empty       (fb_empty[i]      ),
					.fb_suff  		(fb_suff[i]       ), // not needed?
					.fb_full        (fb_full[i] 	  ),
					.di             (mem_di           ),

					.acc_i  		(acc_i[i]   	  ),
					.acc_o  		(acc_o[i]   	  ),
					.acc_o_valid  	(acc_o_valid[i]	  ) // only the last (not tail) conv_unit will be checked.
				);
			
			// Only look at tail: if tail is sufficient, then all others are sufficient.
			assign wb_suff_reduc[i] = (is_tail[i]) ? wb_suff[i] : 0;
			assign fb_suff_reduc[i] = (is_tail[i]) ? fb_suff[i] : 0;

			assign pipe_en_i[i] = (i==0) ? pipe_en   : pipe_en_o[i-1];
			assign acc_i[i] 	= (i==0) ? 0 	     : acc_o[i-1];
		end
	endgenerate 

	assign wb_suff_i = (wb_suff_reduc > 0) ? 1'b1 : 1'b0;
	assign fb_suff_i = (fb_suff_reduc > 0) ? 1'b1 : 1'b0;

	assign wb_full_i = |wb_full;
	assign fb_full_i = |fb_full;

	assign m1_cfg_done = |m1_cfg_done_i;

	// TODO: write output data directly back to fb BRAM until fb BRAM run out of space.
	activation_unit #(
			.N_KERNEL(N_KERNEL),
			.B_PIXEL (B_PIXEL)
		)
		activation_unit_i
		(
			.clk		    (aclk			    ),
			.rstn         	(aresetn	        ),

			.pipe_en		(pipe_en			),

			.type           (act_func           ),

			.di             (acc_o		[N_CONV_UNIT-1]),
			.di_valid	    (acc_o_valid[N_CONV_UNIT-1]),

			.do				(act_do		   			),
			.do_valid		(act_do_vaild  			)
		);
		

	assign act_func  = cfg_i_data[2:0];



    cfg_prop
        #(
			.B    (64),
        )
        cfg_prop_1_i
        (
            .clk  (clk	)	     ,    
            .rstn (rstn )        ,     

			.s_cfg_data  (m1_cfg_data[64+:64] ), // 64-bits
			.s_cfg_valid (m1_cfg_valid 		  ),
			.s_cfg_ready (m1_cfg_ready 		  ),

			.m_cfg_done  (m2_cfg_done	    ),
			.m_cfg_run	 (m2_cfg_run		),
			.m_cfg_data  (m2_cfg_data       ),
			.m_cfg_valid (    		        ),
			.m_cfg_ready (1'b1		        )
        );

	// Whether to cache on BRAM or not, need always write a copy to ddr, since 
		// they may be used several time in different layers.
	// Need to do a lot of addr compute works.
	ddr_writer
		#(
			.N_KERNEL(N_KERNEL),
			.B_PIXEL (B_PIXEL),
			.DATA_WIDTH (DATA_WIDTH),
			.N_DSP_GROUP (N_DSP_GROUP)
		)
		ddr_writer_i
		( 
			.clk    		(aclk				 ),
			.rstn			(aresetn			 ),

			.pipe_en		(pipe_en			 ),

			.cfg_data  		(m2_cfg_data   		 ),
			.cfg_done 	    (m2_cfg_done	 	 ),
			.cfg_run	    (m2_cfg_run 	 	 ),

			// Input data.
			.ddr_valid         (act_do_vaild   ),
			.ddr_data          (act_do         ),
			.ddr_ready         (               ),

			// AXIS Slave.
			.m_axis_tdata 	(s_axis_tdata ),
			.m_axis_tvalid	(s_axis_tvalid ),
			.m_axis_tready	(s_axis_tready )
		);



	assign pipe_en = s_axis_tready & (wb_suff_i) & (fb_suff_i);





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
			.RIDLE_REG      (RDONE_REG      ),

			.WSTART_REG		(WSTART_REG		),
			.WADDR_REG		(WADDR_REG		),
			.WNBURST_REG	(WNBURST_REG	),
			.WIDLE_REG  	(WIDLE_REG	    )
			

			// .probe (probe)
		);




endmodule

