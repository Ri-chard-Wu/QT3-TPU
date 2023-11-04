module ddr_reader
    #(
        parameter N_KERNEL = 4, 
        parameter B_PIXEL = 16,
        parameter DATA_WIDTH = 64,
		parameter BURST_LENGTH = 15
        parameter ADDR_WIDTH = 32	,
        parameter N_DSP_GROUP = 4,

		// The largest kernel [3, 3, 512] == 72 bursts (3*3*512*2 / 128).
		// A ftm that can just fill entire fb (2621.44 kb) == 2560 bursts.
		parameter UNIT_BURSTS_WEI = 32,  // need to be power of 2.
		parameter UNIT_BURSTS_FTM = 1024,  // need to be power of 2.

		
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input  wire                      cfg_i_valid,
        input  wire [FW-1:0]             cfg_i_data ,
        output wire 		             cfg_i_ready,

		output wire [127:0]               cfg_o_data ,
        output wire      	             cfg_o_valid,
        input  wire      	             cfg_o_ready,

		input  wire 					 fifo_empty,
		output wire 					 fifo_rd_en,
		input  wire [63:0]  			 fifo_dout ,
		
        input  wire					 m_axis_tvalid,
        input  wire	[DATA_WIDTH-1:0] m_axis_tdata ,
        output wire					 m_axis_tready,


        output wire   [N_CONV_UNIT-1:0]  wb_we    ,
        output wire   [N_CONV_UNIT-1:0]  wb_clr   ,
        input wire                       wb_suff  ,
        input wire    [N_CONV_UNIT-1:0]  wb_full  , 	
		output wire    [31:0]		     wb_cfg   , 				
        output wire   [N_CONV_UNIT-1:0]  fb_we    ,
        output wire   [N_CONV_UNIT-1:0]  fb_clr   ,
        input wire    			         fb_suff, // not needed?
        input wire    [N_CONV_UNIT-1:0]  fb_full  , 		
		output wire    [31:0]		     fb_cfg   , 			
        output wire   [DATA_WIDTH-1:0]   mem_di   ,


        input wire			             RSTART_REG	,
        input wire	[31:0]	             RADDR_REG	,
        input wire	[31:0]	             RNBURST_REG,
        input wire                       RDONE_REG   
    );

localparam INIT_ST           = 0;
localparam WEI_LATCH_ST		 = 1;	
localparam CFG_WR_ST		 = 2;			
localparam WEI_LOAD_ST   	 = 3;			           
localparam WEI_INCR_ST 		 = 4;		      
localparam CFG_RD_ST		 = 5;	
localparam FTM_FIFO_READ_ST  = 6;    
localparam FTM_LATCH_ST		 = 7;
localparam FTM_LOAD_ST       = 8;  
localparam FTM_INCR_ST       = 9;
localparam FTM_CHECK_N_ST    = 10;

reg init_st	   		;
reg wei_load_st		;
reg wei_incr_st		;
reg ftm_fifo_read_st;
reg ftm_load_st     ;
reg ftm_incr_st     ;
reg wei_latch_st    ;
reg cfg_wr_st       ;
reg cfg_rd_st       ;
reg ftm_latch_st    ;   

reg [3:0] state;



wire 		wei_done      ; 
wire 		wei_pending   ;
wire [31:0] wei_addr    ;
wire [31:0] wei_n_bursts;
wire 		ftm_done      ; 
wire 		ftm_pending   ;
wire [31:0] ftm_addr    ;
wire [31:0] ftm_n_bursts;


wire [3:0]  wei_cu_sel;
wire [3:0]  ftm_cu_sel;
wire [3:0]  cu_sel_i  ;

wire [3:0]  ftm_n_lim;
reg  [3:0]  ftm_n_r  ;
    

wire [63:0] wei_addr_gen_cfg;
wire [63:0] ftm_addr_gen_cfg;

assign wei_addr_gen_cfg = cfg_i_data_r[18+:64];
assign ftm_addr_gen_cfg = fifo_dout   [0 +:64];


always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
		
		state	   <= INIT_ST;

		ftm_n_r	   <= 0;
    end 
    else begin    

		// Update wr's cfg -> 
		// Load wei until suff -> 
		// After suff, if rd is still not ready for cfg, keep loading wei.
			// Else, update rd's cfg and load ftm until done. 
			// If wei is done while rd is still not ready, idle wait until rd is ready. -> 
		// Load wei until done -> go back to first step and repeat.

		case(state)

			INIT_ST:
                if (cfg_i_valid == 1'b1) // Will set fifo_rd_en to 1.
                    state <= WEI_LATCH_ST;

			// Need to preload until suff for next layer.
			// CFG_WR_ST:
			// 	if (cfg_o_ready[0])
			// 		if (~wb_full)
			// 			state <= WEI_LATCH_ST;			
		
			WEI_LATCH_ST: 
				if (~wb_full)
					state <= WEI_INCR_ST;

			WEI_INCR_ST:
					state <= WEI_LOAD_ST;
   
			WEI_LOAD_ST:
				if (RDONE_REG) begin 

					if ((cfg_o_ready && wb_suff)) 
						if (~wei_pending)
							state <= FTM_FIFO_READ_ST;
							// state <= CFG_RD_ST;
					else if(~wb_full && ~wei_done) 
						state <= WEI_INCR_ST;
					else if (ftm_done_n_i && wei_done)
						state <= INIT_ST;						
				end

			// CFG_RD_ST: // check cfg_ready of its downstream.
			// 	if (cfg_o_ready[1]) 
			// 		state <= FTM_FIFO_READ_ST;
					
			FTM_FIFO_READ_ST: 
				// if (cfg_o_ready[0])
					state <= FTM_LATCH_ST;

			FTM_LATCH_ST:
				state <= FTM_INCR_ST;

			FTM_INCR_ST:
				if(~fb_full) // full won't happen.
					state <= FTM_LOAD_ST;

			FTM_LOAD_ST:	
				if (RDONE_REG) begin // When mst_read in END state.
					if (ftm_done) 
						if (~ftm_pending)
							state <= FTM_CHECK_N_ST;
					else
						state <= FTM_INCR_ST;
				end

			FTM_CHECK_N_ST:
				if (ftm_n_r == ftm_n_lim)
					state <= WEI_INCR_ST;
				else
					state <= FTM_FIFO_READ_ST;
		endcase	


		if (init_st == 1'b1 && cfg_i_valid == 1'b1) 
			cfg_i_data_r <= cfg_i_data;
		

		if (init_st == 1'b1) 
			ftm_n_r <= 0;		
		else if (fifo_rd_en == 1'b1) 
			ftm_n_r <= ftm_n_r + 1;

    end
end    


    addr_gen
        #(
			.DATA_WIDTH (DATA_WIDTH),
			.BURST_LENGTH (BURST_LENGTH),
			.UNIT_BURSTS (UNIT_BURSTS_WEI),
        )
        wb_addr_gen_i
        (
            .clk  	  (clk		       ),    
            .rstn 	  (rstn 	       ),     

			.cfg	  (wei_addr_gen_cfg),

			.latch_en (wei_latch_st    ),
			.incr_en  (wei_incr_st     ),
			.mem_we   (mem_we          ),

			.addr     (wei_addr        ),
			.nbursts  (wei_n_bursts    ),

			.pending  (wei_pending     ),
			.done     (wei_done        ),
			.cu_sel   (wei_cu_sel      )
        );

    addr_gen
        #(
			.DATA_WIDTH (DATA_WIDTH),
			.BURST_LENGTH (BURST_LENGTH),			
			.UNIT_BURSTS_FTM (UNIT_BURSTS_FTM),
        )
        fb_addr_gen_i
        (
            .clk  	  (clk		    ),    
            .rstn 	  (rstn 	    ),     

			.cfg	  (ftm_addr_gen_cfg),

			.latch_en (ftm_latch_st ),
			.incr_en  (ftm_incr_st  ),
			.mem_we   (mem_we       ),

			.addr     (ftm_addr      ),
			.nbursts  (ftm_n_bursts  ),

			.pending  (ftm_pending ),
			.done     (ftm_done    ),
			.cu_sel   (ftm_cu_sel  )
        );

generate
genvar i;
	for (i=0; i < N_CONV_UNIT; i=i+1) begin : GEN_CONV_UNIT
		
		// Use en[i] to select one the N_CONV_UNIT conv_units.
		// Use wei_pending and ftm_pending to select one of wb or fb.
		assign wb_we[i] = (cu_sel_i == i) ? (wei_pending ? mem_we : 0) : 0;
		assign fb_we[i] = (cu_sel_i == i) ? (ftm_pending ? mem_we : 0) : 0;
	end
endgenerate 

assign RSTART_REG  = wei_load_st | ftm_load_st;	 
assign RADDR_REG   = (wei_load_st) ? wei_addr :
					 (ftm_load_st) ? ftm_addr : 0;
assign RNBURST_REG = (wei_load_st) ? wei_n_bursts :
				     (ftm_load_st) ? ftm_n_bursts : 0; 


// 128-bits
assign cfg_o_data  = {
				// out_addr: 32-bits, out_shape: 32-bits.
				cfg_i_data_r[178+:32], cfg_i_data_r[210+:32],

				// n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits.
				fifo_dout[57+:7], 
				
				// n_wrap_c1: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits.
				cfg_i_data_r[114+:25], cfg_i_data_r[82+:32]
				
				}; 



// assign cfg_o_valid = (cfg_wr_st == 1'b1 || ftm_latch_st == 1'b1) ? 2'b10 : 
// 					 (cfg_rd_st == 1'b1						   ) ? 2'b01 :2'b00;

		

	
assign cfg_o_valid = (~init_st);

assign cfg_i_ready = init_st;

assign fifo_rd_en = ftm_fifo_read_st;

assign ftm_done_n_i = ftm_done && (ftm_n_r == ftm_n_lim);

assign ftm_n_lim  = cfg_i_data_r[139+:4];

assign cu_sel_i = wei_pending ? wei_cu_sel : 
				  ftm_pending ? ftm_cu_sel : 0;





// FSM outputs.
always @(state) begin

    init_st	     	   = 0;
	wei_load_st  	   = 0;
	wei_incr_st  	   = 0;
	ftm_fifo_read_st   = 0;
	ftm_load_st   	   = 0;	
	ftm_incr_st   	   = 0;
	wei_latch_st  	   = 0;
	cfg_wr_st     	   = 0;
	cfg_rd_st     	   = 0;
	ftm_latch_st  	   = 0;   

	case (state)

		INIT_ST:
			init_st       = 1;

		WEI_LATCH_ST:
			wei_latch_st  = 1;

		CFG_WR_ST:
			cfg_wr_st     = 1;

		WEI_INCR_ST:
			wei_incr_st   = 1;

		WEI_LOAD_ST:
			wei_load_st   = 1;

		CFG_RD_ST:
			cfg_rd_st     = 1;

		FTM_FIFO_READ_ST:
			ftm_fifo_read_st   = 1;	

		FTM_LATCH_ST:
			ftm_latch_st   = 1;

		FTM_LOAD_ST:
			ftm_load_st   = 1;	

		FTM_INCR_ST:
			ftm_incr_st   = 1;
	endcase
end


fifo_axi_reader
    #(
        .DATA_WIDTH  (DATA_WIDTH),
		.N_CONV_UNIT (N_CONV_UNIT)
    )
    fifo_axi_reader_i
	( 
        .clk    		(clk			),
		.rstn			(rstn		),

		// AXIS Slave.
		.s_axis_tdata	(m_axis_tdata  ),
		.s_axis_tvalid	(m_axis_tvalid ),
		.s_axis_tready	(m_axis_tready ),

		// Output data.
        .mem_we         (mem_we         ),
        .mem_di         (mem_di         )
    );



endmodule