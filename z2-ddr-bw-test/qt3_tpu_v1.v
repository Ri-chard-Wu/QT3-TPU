

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
		parameter FW    = 253,
		parameter UNIT_BURSTS = 2048, // need to be power of 2.
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



wire [31:0] acc;




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



wire [2*B_PIXEL*N_KERNEL-1:0] acc_i [0:N_CONV_UNIT-1];
wire [2*B_PIXEL*N_KERNEL-1:0] acc_o [0:N_CONV_UNIT-1];
wire [B_INST-1:0]  inst_i        [0:N_CONV_UNIT-1];
wire [B_INST-1:0]  inst_o        [0:N_CONV_UNIT-1];


wire   [N_CONV_UNIT-1:0]  wb_we    ;
wire   [N_CONV_UNIT-1:0]  wb_clr   ;
wire   [N_CONV_UNIT-1:0]  wb_empty ;
wire   [N_CONV_UNIT-1:0]  fb_we    ;
wire   [N_CONV_UNIT-1:0]  fb_clr   ;
wire   [N_CONV_UNIT-1:0]  fb_empty ;
wire [DATA_WIDTH-1:0]     mem_di   ;



wire          fifo_wr_en_i;
wire [FW-1:0] fifo_din_i  ;
wire 		  fifo_ready_i;


reg  [3:0] wei_cu_sel;
reg  [3:0] ftm_cu_sel;
wire [3:0] cu_sel_i;


localparam INIT_ST     = 0;
localparam WEI_LOAD_ST = 1;   
localparam WEI_INIT_ST = 2;    
localparam WEI_INCR_ST = 3;    
localparam FTM_LOAD_ST  = 4;  
localparam FTM_INIT_ST  = 5;
localparam FTM_INCR_ST  = 6;

reg init_st	   ;
reg wei_load_st;
reg wei_init_st;
reg wei_incr_st;
reg ftm_load_st;
reg ftm_init_st;
reg ftm_incr_st;

reg [3:0] state;




wire [17:0] oper 		   	    ;
wire [2:0]  act_func	   	    ;

wire [31:0] wei_addr 		    ;
wire [6:0]  wei_n_last_burst    ;
wire [24:0] wei_n_rema_bursts   ;

wire [31:0] ftm_addr 	  	    ;
wire [6:0]  ftm_n_last_burst    ;
wire [24:0] ftm_n_rema_bursts   ;


wire [63:0] conv_para           ;
wire 		conv_para_we		;

wire [31:0] wei_shape  ;
wire [31:0] ftm_shape  ;
wire [31:0] out_shape  ;

wire [31:0] out_addr            ;



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

        .fifo_wr_en     (fifo_wr_en_i),
        .fifo_din       (fifo_din_i  ),
		.fifo_ready     (fifo_ready_i)
	);


assign oper	    = fifo_din_i[28:11]; // 18-bits.
assign act_func = oper[2:0];

assign wei_addr 		 = fifo_din_i[31:0];
assign wei_n_last_burst  = fifo_din_i[38:32]; // number of valid bytes in last burst.
assign wei_n_rema_bursts = fifo_din_i[63:39]; // each burst is 128 bytes (16 * 64-bits).

assign ftm_addr 	  	 = fifo_din_i[95:64];
assign ftm_n_last_burst  = fifo_din_i[102:96];
assign ftm_n_rema_bursts = fifo_din_i[127:103];

assign conv_para         = fifo_din_i[191:128];
assign out_addr          = fifo_din_i[223:192];


assign w1  = conv_para[5:4]; 
assign h1  = conv_para[7:6]  ; 
assign c2  = conv_para[31:20];

assign pad    = conv_para[3:2] ;
assign stride = conv_para[1:0] ;

assign k1      = conv_para[9:0] ;
assign k2     = conv_para[19:10]; 

// Requirement: 2 * pad + 1 == k1 == k2.
assign out_shape[9:0]        =  w1; // w
assign out_shape[19:10]      =  h1; // h
assign out_shape[31:20]      =  c2; // c

// Assume c1 is divisible by N_CONV_UNIT in the case of c1 > N_CONV_UNIT.
// assign c1 = conv_para[19:8];
// assign id_last = (c1 > N_CONV_UNIT) ? N_CONV_UNIT - 1 : c1 - 1; 


reg [31:0] wei_addr_r 		   ;
reg [24:0] wei_n_rema_bursts_r ;
reg [24:0] wei_n_bursts_r      ;
reg [31:0] wei_cnt_incr_r      ;
reg [31:0] wei_cnt_r           ;

reg [31:0] ftm_addr_r  	  	   ;
reg [24:0] ftm_n_rema_bursts_r ;
reg [24:0] ftm_n_bursts_r      ;
reg [31:0] ftm_cnt_incr_r      ;
reg [31:0] ftm_cnt_r           ;



wire [N_CONV_UNIT-1:0] wb_sufficient       ;
wire [N_CONV_UNIT-1:0] wb_sufficient_reduc ;
wire [N_CONV_UNIT-1:0] wb_full             ;           
wire [N_CONV_UNIT-1:0] fb_sufficient       ; 
wire [N_CONV_UNIT-1:0] fb_full             ;         

wire wb_sufficient_i ;
wire wb_full_i       ;           
wire wb_done_i       ;    
wire fb_sufficient_i ; 
wire fb_full_i       ;         
wire fb_done_i       ;    
  




always @( posedge aclk )
begin
    if ( aresetn == 1'b0 ) begin
		
		state	   <= INIT_ST;

		wei_cu_sel <= 0;
		ftm_cu_sel <= 0;	

		wei_addr_r 		    <= 0;
		wei_n_rema_bursts_r <= 0;  
		wei_n_bursts_r      <= 0;  
		wei_cnt_incr_r      <= 0;  
		wei_cnt_r           <= 0;  

		ftm_addr_r  	  	<= 0;  
		ftm_n_rema_bursts_r <= 0;  
		ftm_n_bursts_r      <= 0;  
		ftm_cnt_incr_r      <= 0;  
		ftm_cnt_r           <= 0; 

    end 
    else begin    


		// load wei until sufficient -> load fm until done -> load wei until done -> pre-load next layer.
		case(state)

			INIT_ST:
                if (fifo_wr_en_i == 0)
                    state <= WEI_INIT_ST;
			
			WEI_INIT_ST:
				state <= WEI_LOAD_ST;

			WEI_INCR_ST:
				if(~wb_full_i)
					state <= WEI_LOAD_ST;

			WEI_LOAD_ST:
				if (RDONE_REG) begin // When mst_read in END state.
					if (wb_sufficient_i && ~fb_done_i) 
						if (~wei_pending_i)
							state <= FTM_INIT_ST;
					else if (wb_done_i)
						if (~wei_pending_i)
							state <= INIT_ST;
					else
						state <= WEI_INCR_ST;
				end

			FTM_INIT_ST:
				state <= FTM_LOAD_ST;

			FTM_INCR_ST:
				if(~fb_full_i)
					state <= FTM_LOAD_ST;

			FTM_LOAD_ST:	
				if (RDONE_REG) begin // When mst_read in END state.
					if (fb_done_i && ~ftm_pending_i)
						if (~ftm_pending_i)
							state <= WEI_INCR_ST;
					else
						state <= FTM_INCR_ST;
				end
		endcase	


		if (wei_init_st == 1'b1) begin

			wei_addr_r <= wei_addr;

			if (UNIT_BURSTS >= wei_n_rema_bursts) begin // will include the last burst.

				wei_n_rema_bursts_r <= 0;
				wei_n_bursts_r		<= wei_n_rema_bursts;
				wei_cnt_incr_r	    <= ((wei_n_rema_bursts - 1) << ($clog2(BYTES_PER_BURST))) + wei_n_last_burst;
			end
			else begin

				wei_n_rema_bursts_r <= wei_n_rema_bursts - UNIT_BURSTS;
				wei_n_bursts_r		<= UNIT_BURSTS;
				wei_cnt_incr_r	    <= (UNIT_BURSTS << ($clog2(BYTES_PER_BURST)));
			end
		end
		else if (wei_incr_st == 1'b1) begin

			wei_addr_r <= wei_addr_r + (wei_n_bursts_r << ($clog2(BYTES_PER_BURST)));

			if (UNIT_BURSTS >= wei_n_rema_bursts_r) begin // will include the last burst.
				
				wei_n_rema_bursts_r <= 0;
				wei_n_bursts_r		<= wei_n_rema_bursts_r;
				wei_cnt_incr_r	    <= wei_cnt_incr_r + 
					((wei_n_rema_bursts_r - 1) << ($clog2(BYTES_PER_BURST))) + wei_n_last_burst;
			end
			else begin

				wei_n_rema_bursts_r <= wei_n_rema_bursts_r - UNIT_BURSTS;
				wei_n_bursts_r		<= UNIT_BURSTS;
				wei_cnt_incr_r	    <= wei_cnt_incr_r + (UNIT_BURSTS << ($clog2(BYTES_PER_BURST)));
			end	
		end


		if (wei_init_st == 1'b1) begin
			wei_cu_sel <= 0;	
			wei_cnt_r <= 0;	
		end
		else if (mem_we == 1'b1) begin		
			
			wei_cnt_r <= wei_cnt_r + BYTES_PER_AXI_TRANSFER;

			// TODO: should be min(N_CONV_UNIT, c1).
			// TODO: consider replace following with local checks in each conv_units: 
				// pass down sel signal in cyclic order. Since they know whethe themselves are the tail,
				// so it would be convenit to know when to wrap.
			if (wei_cu_sel == N_CONV_UNIT-1) 
				wei_cu_sel <= 0;
			else
				wei_cu_sel <= wei_cu_sel + 1;
		end		





		// following codes are the same as above, just replace `wei_` by `ftm_`

		if (ftm_init_st == 1'b1) begin

			ftm_addr_r <= ftm_addr;

			if (UNIT_BURSTS >= ftm_n_rema_bursts) begin // will include the last burst.

				ftm_n_rema_bursts_r <= 0;
				ftm_n_bursts_r		<= ftm_n_rema_bursts;
				ftm_cnt_incr_r	    <= ((ftm_n_rema_bursts - 1) << ($clog2(BYTES_PER_BURST))) + ftm_n_last_burst;
			end
			else begin

				ftm_n_rema_bursts_r <= ftm_n_rema_bursts - UNIT_BURSTS;
				ftm_n_bursts_r		<= UNIT_BURSTS;
				ftm_cnt_incr_r	    <= (UNIT_BURSTS << ($clog2(BYTES_PER_BURST)));
			end
		end
		else if (ftm_incr_st == 1'b1) begin

			ftm_addr_r <= ftm_addr_r + (ftm_n_bursts_r << ($clog2(BYTES_PER_BURST)));

			if (UNIT_BURSTS >= ftm_n_rema_bursts_r) begin // will include the last burst.
				
				ftm_n_rema_bursts_r <= 0;
				ftm_n_bursts_r		<= ftm_n_rema_bursts_r;
				ftm_cnt_incr_r	    <= ftm_cnt_incr_r + 
					((ftm_n_rema_bursts_r - 1) << ($clog2(BYTES_PER_BURST))) + ftm_n_last_burst;
			end
			else begin

				ftm_n_rema_bursts_r <= ftm_n_rema_bursts_r - UNIT_BURSTS;
				ftm_n_bursts_r		<= UNIT_BURSTS;
				ftm_cnt_incr_r	    <= ftm_cnt_incr_r + (UNIT_BURSTS << ($clog2(BYTES_PER_BURST)));
			end	
		end


		if (ftm_init_st == 1'b1) begin
			ftm_cu_sel <= 0;	
			ftm_cnt_r <= 0;	
		end
		else if (mem_we == 1'b1) begin		
			
			ftm_cnt_r <= ftm_cnt_r + BYTES_PER_AXI_TRANSFER;

			if (ftm_cu_sel == N_CONV_UNIT-1)
				ftm_cu_sel <= 0;
			else
				ftm_cu_sel <= ftm_cu_sel + 1;
		end		

    end
end    


assign RSTART_REG  = wei_load_st | ftm_load_st;	 
assign RADDR_REG   = (wei_load_st) ? wei_addr_r :
					 (ftm_load_st) ? ftm_addr_r : 0;
assign RNBURST_REG = (wei_load_st) ? wei_n_bursts_r :
				     (ftm_load_st) ? ftm_n_bursts_r : 0; 


assign wb_done_i = (wei_n_rema_bursts_r == 0) ? 1'b1 : 1'b0;
assign fb_done_i = (ftm_n_rema_bursts_r == 0) ? 1'b1 : 1'b0;


// FSM outputs.
always @(state) begin

    init_st	      = 0;
	wei_load_st   = 0;
	wei_init_st   = 0;
	wei_incr_st   = 0;
	ftm_load_st   = 0;	
	ftm_init_st   = 0;
	ftm_incr_st   = 0;

	case (state)

		INIT_ST:
			init_st       = 1;

		WEI_LOAD_ST
			wei_load_st   = 1;

		WEI_INIT_ST:
			wei_init_st   = 1;

		WEI_INCR_ST:
			wei_incr_st   = 1;

		FTM_LOAD_ST:
			ftm_load_st   = 1;	

		FTM_INIT_ST:
			ftm_init_st   = 1;

		FTM_INCR_ST:
			ftm_incr_st   = 1;
	endcase
end





assign fifo_ready_i = init_st;

assign cu_sel_i = wei_pending_i ? wei_cu_sel : 
				  ftm_pending_i ? ftm_cu_sel : 0;



ddr_reader
    #(
        .DATA_WIDTH  (DATA_WIDTH),
		.N_CONV_UNIT (N_CONV_UNIT)
    )
    ddr_reader_i
	( 
        .clk    		(aclk			),
		.rstn			(aresetn		),

		// AXIS Slave.
		.s_axis_tdata	(m_axis_tdata  ),
		.s_axis_tvalid	(m_axis_tvalid ),
		.s_axis_tready	(m_axis_tready ),

		// Output data.
        .mem_we         (mem_we         ),
        .mem_di         (mem_di             )
    );



wire          		   pipe_en  ;
wire [N_CONV_UNIT-1:0] pipe_en_i;
wire [N_CONV_UNIT-1:0] pipe_en_o;

wire [N_CONV_UNIT-1:0] acc_o_valid;


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

				.para           (conv_para      ),
				.para_we        (conv_para_we   ),


				// TODO: implement full logic. Need to first figure 
					// out how to read from strided buffer in each conv_unit.

				.wb_sufficient  (wb_sufficient[i]  ),
				.wb_full        (wb_full      [i]  ),
				.fb_sufficient  (fb_sufficient[i]  ),
				.fb_full        (fb_full      [i]  ),


				// TODO: implement clr logic to clear regs in 
					// all conv_unit to be ready for next layer.
				.wb_we          (wb_we[i]         ),
				.wb_clr         (wb_clr[i]        ),
				.wb_empty       (wb_empty[i]      ),
				.fb_we          (fb_we[i]         ),
				.fb_clr         (fb_clr[i]        ),
				.fb_empty       (fb_empty[i]      ),
				.di             (di               ),

				.acc_i  		(acc_i[i]   	  ),
				.acc_o  		(acc_o[i]   	  ),
				.acc_o_valid  	(acc_o_valid[i]	  ), // only the last (not tail) conv_unit will be checked.

				.inst_i			(inst_i[i]		  ),
				.inst_o			(inst_o[i]		  ),
			);
		

		// Use en[i] to select one the N_CONV_UNIT conv_units.
		// Use wei_pending_i and ftm_pending_i to select one of wb or fb.
		assign en[i]    = (cu_sel_i == i) ? 1 : 0;
		assign wb_we[i] = en[i] & (wei_pending_i ? mem_we : 0);
		assign fb_we[i] = en[i] & (ftm_pending_i ? mem_we : 0);
		
		// Only look at tail: if tail is sufficient, then all others are sufficient.
		assign wb_sufficient_reduc[i] = (is_tail[i]) ? wb_sufficient[i] : 0;

		assign pipe_en_i[i] = (i==0) ? 0 	     : pipe_en_o[i-1];
        assign acc_i[i] 	= (i==0) ? 0 	     : acc_o_arr[i-1];
        assign inst_i[i]	= (i==0) ? conv_inst : inst_o[i-1];
	end
endgenerate 

assign wb_sufficient_i = (wb_sufficient_reduc > 0) ? 1'b1 : 1'b0;

assign conv_para_we = fifo_wr_en_i & init_st;

assign wei_pending_i = (wei_cnt_r == wei_cnt_incr_r) ? 0 : 1;
assign ftm_pending_i = (ftm_cnt_r == ftm_cnt_incr_r) ? 0 : 1;



wire [N_KERNEL*B_PIXEL:0] act_do;
wire 					  act_do_vaild;

// TODO: write output data directly back to fb BRAM until fb BRAM run out of space.
activation_unit #(
		.N_KERNEL(N_KERNEL),
		.B_PIXEL (B_PIXEL)
	)
	activation_unit_i
	(
		.clk		    (aclk			      		   ),
		.rstn         	(aresetn					   ),

		.type           (act_func             		   ),

		.di             (acc_o		[N_CONV_UNIT-1]),
		.di_valid	    (acc_o_valid[N_CONV_UNIT-1]),

		.do				(act_do		   			),
		.do_valid		(act_do_vaild  			)
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
        .clk    		(aclk			),
		.rstn			(aresetn		),

		.base_addr	 	(out_addr       ),

		// Input data.
        .ddr_we         (act_do_vaild   ),
        .ddr_di         (act_do         ),


		// AXIS Slave.
		.m_axis_tdata 	(s_axis_tdata ),
		.m_axis_tvalid	(s_axis_tvalid ),
		.m_axis_tready	(s_axis_tready )
    );







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

