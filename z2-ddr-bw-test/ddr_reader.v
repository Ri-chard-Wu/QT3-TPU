module ddr_reader
    #(
        parameter N_KERNEL = 4, 
        parameter B_PIXEL = 16,
        parameter DATA_WIDTH = 64,
        parameter ADDR_WIDTH = 32	,
        parameter N_DSP_GROUP = 4,

		// The largest kernel [3, 3, 512] == 72 bursts (3*3*512*2 / 128).
		// A ftm that can just fill entire fb (2621.44 kb) == 2560 bursts.
		parameter UNIT_BURSTS_WEI = 32,  // need to be power of 2.
		parameter UNIT_BURSTS_FTM = 1024  // need to be power of 2.			
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input  wire                      cfg_i_valid,
        input  wire [FW-1:0]             cfg_i_data ,
        output wire 		             cfg_i_ready,

        output wire                      cfg_o_valid,
        output wire [63:0]               cfg_o_data ,
        input  wire 		             cfg_o_ready,

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


reg  [3:0] wei_cu_sel;
reg  [3:0] ftm_cu_sel;
wire [3:0] cu_sel_i;


localparam INIT_ST      = 0;
localparam WEI_LOAD_ST  = 1;   
localparam WEI_INIT_ST  = 2;    
localparam WEI_INCR_ST  = 3;
localparam FTM_FIFO_READ_ST  = 4;    
localparam FTM_LOAD_ST  = 5;  
localparam FTM_INIT_ST  = 6;
localparam FTM_INCR_ST  = 7;
localparam FTM_CHECK_N_ST  = 8;


reg init_st	   ;
reg wei_load_st;
reg wei_init_st;
reg wei_incr_st;
reg ftm_fifo_read_st;
reg ftm_load_st;
reg ftm_init_st;
reg ftm_incr_st;

reg [3:0] state;

wire [31:0] wei_addr 		    ;
wire [6:0]  wei_n_last_burst    ;
wire [24:0] wei_n_rema_bursts   ;
wire [31:0] wei_ld_cfg 	  	    ;

wire [31:0] ftm_addr 	  	    ;
wire [6:0]  ftm_n_last_burst    ;
wire [24:0] ftm_n_rema_bursts   ;


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


wire [3:0] ftm_n_lim;
reg  [3:0] ftm_n_r;
    
wire wb_done_i ;          
wire fb_done_i ;    
  

assign wei_addr 		 = cfg_i_data_r[18+:32]; // $r0
assign wei_ld_cfg        = cfg_i_data_r[50+:32]; // $r1
assign wei_n_last_burst  = wei_ld_cfg[0+:7];  // number of valid bytes in last burst.
assign wei_n_rema_bursts = wei_ld_cfg[7+:18]; // each burst is 128 bytes (16 * 64-bits).

// n_wrap_c_acc: 7-bits, n_bursts: 18-bits, valid_bytes_in_last_burst: 7-bits
assign ftm_n_last_burst  = fifo_dout[32+:7];
assign ftm_n_rema_bursts = fifo_dout[39+:18];
assign ftm_addr 	  	 = fifo_dout[0+:32];



always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
		
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

		ftm_n_r				<= 0;
    end 
    else begin    


		// load wei until sufficient -> load fm until done -> load wei until done -> pre-load next layer.
		case(state)

			INIT_ST:
                if (cfg_i_valid == 1'b1)
                    state <= INIT2_ST;

			INIT2_ST:
				state <= CFG_SEL_ST;

			CFG_SEL_ST:
				if (cfg_o_ready[0] & cfg_o_ready[1]) // can update both wr's & rd's cfg.
					state <= CFG_RDWR_ST;
				else if (cfg_o_ready[0]) // can only update wr's cfg.
					state <= CFG_WR_ST;

			CFG_RDWR_ST:
				state <= WEI_INIT_ST;

			CFG_RD_ST:
				if (~wb_suff) 
					state <= WEI_INIT_ST;
				else
					state <= FTM_FIFO_READ_ST;
					
			CFG_WR_ST:
				state <= PRELOAD_INIT_ST;
			
			PRELOAD_INIT_ST:
				if (cfg_o_ready[1])
					state <= CFG_RD_ST;
				else if (~wb_full)
					state <= PRELOAD_LOAD_ST;

			PRELOAD_INCR_ST:
				if (cfg_o_ready[1])
					state <= CFG_RD_ST;			
				else if(~wb_full) // might happen when try to pre-loaded kernels.
					state <= PRELOAD_LOAD_ST;
   
			PRELOAD_LOAD_ST:
				if (RDONE_REG) begin // When mst_read in END state.
					if (cfg_o_ready[1]) 
						if (~wei_pending_i)
							state <= CFG_RD_ST;
					else if (wb_done_i)
						if (~wei_pending_i)
							state <= PRELOAD_WAIT_ST;
					else
						state <= PRELOAD_INCR_ST;
				end

			PRELOAD_WAIT_ST:
				if (cfg_o_ready[1]) 
					state <= CFG_RD_ST;

			WEI_INIT_ST:
				if(~wb_full)
					state <= WEI_LOAD_ST;

			WEI_INCR_ST:
				if(~wb_full) // might happen when try to pre-loaded kernels.
					state <= WEI_LOAD_ST;
   
			WEI_LOAD_ST:
				if (RDONE_REG) begin // When mst_read in END state.
					if (wb_suff && ~fb_done_i) 
						if (~wei_pending_i)
							state <= FTM_FIFO_READ_ST;
					else if (wb_done_i)
						if (~wei_pending_i)
							state <= INIT_ST;
					else
						state <= WEI_INCR_ST;
				end

			FTM_FIFO_READ_ST:
				state <= FTM_INIT_ST;

			FTM_INIT_ST:
				if(~fb_full)
					state <= FTM_LOAD_ST;

			FTM_INCR_ST:
				if(~fb_full) // won't happen, because ftm won't be pre-loaded.
					state <= FTM_LOAD_ST;

			FTM_LOAD_ST:	
				if (RDONE_REG) begin // When mst_read in END state.
					if (fb_done_i)
						if (~ftm_pending_i)
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
		

		if (init2_st == 1'b1) begin

			wei_addr_r <= wei_addr;

			if (UNIT_BURSTS_WEI >= wei_n_rema_bursts) begin // will include the last burst.

				wei_n_rema_bursts_r <= 0;
				wei_n_bursts_r		<= wei_n_rema_bursts;
			end
			else begin

				wei_n_rema_bursts_r <= wei_n_rema_bursts - UNIT_BURSTS_WEI;
				wei_n_bursts_r		<= UNIT_BURSTS_WEI;
			end
		end


		if (wei_init_st == 1'b1) begin

			if (UNIT_BURSTS_WEI >= wei_n_rema_bursts)  // will include the last burst.
				wei_cnt_incr_r	    <= ((wei_n_rema_bursts - 1) << ($clog2(BYTES_PER_BURST))) + wei_n_last_burst;
			else 
				wei_cnt_incr_r	    <= (UNIT_BURSTS_WEI << ($clog2(BYTES_PER_BURST)));			
		end
		else if (wei_incr_st == 1'b1) begin

			wei_addr_r <= wei_addr_r + (wei_n_bursts_r << ($clog2(BYTES_PER_BURST)));

			if (UNIT_BURSTS_WEI >= wei_n_rema_bursts_r) begin // will include the last burst.
				
				wei_n_rema_bursts_r <= 0;
				wei_n_bursts_r		<= wei_n_rema_bursts_r;
				wei_cnt_incr_r	    <= wei_cnt_incr_r + 
					((wei_n_rema_bursts_r - 1) << ($clog2(BYTES_PER_BURST))) + wei_n_last_burst;
			end
			else begin

				wei_n_rema_bursts_r <= wei_n_rema_bursts_r - UNIT_BURSTS_WEI;
				wei_n_bursts_r		<= UNIT_BURSTS_WEI;
				wei_cnt_incr_r	    <= wei_cnt_incr_r + (UNIT_BURSTS_WEI << ($clog2(BYTES_PER_BURST)));
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


		if (init2_st == 1'b1) begin

			ftm_addr_r <= ftm_addr;

			if (UNIT_BURSTS_FTM >= ftm_n_rema_bursts) begin // will include the last burst.

				ftm_n_rema_bursts_r <= 0;
				ftm_n_bursts_r		<= ftm_n_rema_bursts;
			end
			else begin

				ftm_n_rema_bursts_r <= ftm_n_rema_bursts - UNIT_BURSTS_FTM;
				ftm_n_bursts_r		<= UNIT_BURSTS_FTM;
			end
		end


		if (ftm_init_st == 1'b1) begin

			ftm_addr_r <= ftm_addr;

			if (UNIT_BURSTS_FTM >= ftm_n_rema_bursts) // will include the last burst.
				ftm_cnt_incr_r	    <= ((ftm_n_rema_bursts - 1) << ($clog2(BYTES_PER_BURST))) + ftm_n_last_burst;
			else 
				ftm_cnt_incr_r	    <= (UNIT_BURSTS_FTM << ($clog2(BYTES_PER_BURST)));			
		end
		else if (ftm_incr_st == 1'b1) begin

			ftm_addr_r <= ftm_addr_r + (ftm_n_bursts_r << ($clog2(BYTES_PER_BURST)));

			if (UNIT_BURSTS_FTM >= ftm_n_rema_bursts_r) begin // will include the last burst.
				
				ftm_n_rema_bursts_r <= 0;
				ftm_n_bursts_r		<= ftm_n_rema_bursts_r;
				ftm_cnt_incr_r	    <= ftm_cnt_incr_r + 
					((ftm_n_rema_bursts_r - 1) << ($clog2(BYTES_PER_BURST))) + ftm_n_last_burst;
			end
			else begin

				ftm_n_rema_bursts_r <= ftm_n_rema_bursts_r - UNIT_BURSTS_FTM;
				ftm_n_bursts_r		<= UNIT_BURSTS_FTM;
				ftm_cnt_incr_r	    <= ftm_cnt_incr_r + (UNIT_BURSTS_FTM << ($clog2(BYTES_PER_BURST)));
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


		if (init_st == 1'b1) 
			ftm_n_r <= 0;		
		else if (ftm_fifo_read_st == 1'b1) 
			ftm_n_r <= ftm_n_r + 1;

    end
end    


assign RSTART_REG  = wei_load_st | ftm_load_st;	 
assign RADDR_REG   = (wei_load_st) ? wei_addr_r :
					 (ftm_load_st) ? ftm_addr_r : 0;
assign RNBURST_REG = (wei_load_st) ? wei_n_bursts_r :
				     (ftm_load_st) ? ftm_n_bursts_r : 0; 


assign wb_done_i = (wei_n_rema_bursts_r == 0) ? 1'b1 : 1'b0;
assign fb_done_i = (ftm_n_rema_bursts_r == 0) ? 1'b1 : 1'b0;


assign cfg_o_valid = (cfg_rdwr_st  == 1'b1) ? 2'b11 : 
			   		 (cfg_wr_st    == 1'b1) ? 2'b10 : 
					 (cfg_rd_st    == 1'b1) ? 2'b01 :2'b00;




// FSM outputs.
always @(state) begin

    init_st	     	   = 0;
	wei_load_st  	   = 0;
	wei_init_st  	   = 0;
	wei_incr_st  	   = 0;
	ftm_fifo_read_st   = 0;
	ftm_load_st   	   = 0;	
	ftm_init_st   	   = 0;
	ftm_incr_st   	   = 0;


	case (state)

		INIT_ST:
			init_st       = 1;

		WEI_LOAD_ST
			wei_load_st   = 1;

		WEI_INIT_ST:
			wei_init_st   = 1;

		WEI_INCR_ST:
			wei_incr_st   = 1;

		FTM_FIFO_READ_ST:
			ftm_fifo_read_st   = 1;	

		FTM_LOAD_ST:
			ftm_load_st   = 1;	

		FTM_INIT_ST:
			ftm_init_st   = 1;

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


generate
genvar i;
	for (i=0; i < N_CONV_UNIT; i=i+1) begin : GEN_CONV_UNIT
		
		// Use en[i] to select one the N_CONV_UNIT conv_units.
		// Use wei_pending_i and ftm_pending_i to select one of wb or fb.
		assign wb_we[i] = (cu_sel_i == i) ? (wei_pending_i ? mem_we : 0) : 0;
		assign fb_we[i] = (cu_sel_i == i) ? (ftm_pending_i ? mem_we : 0) : 0;
	end
endgenerate 


assign fifo_rd_en = ftm_fifo_read_st;

assign wei_pending_i = (wei_cnt_r == wei_cnt_incr_r) ? 0 : 1;
assign ftm_pending_i = (ftm_cnt_r == ftm_cnt_incr_r) ? 0 : 1;

assign cu_sel_i = wei_pending_i ? wei_cu_sel : 
				  ftm_pending_i ? ftm_cu_sel : 0;


assign cfg_i_ready = init_st;
// assign cfg_i_ready = cfg_st;




// // [n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits].
// assign fb_cfg = {fifo_dout[57+:7], cfg_data[114+:25]}; // $r3 
// assign wb_cfg = cfg_data[82+:32]; // $r2 // n_wrap_c1: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits.

// {fb_cfg, wb_cfg}
	// fb_cfg == [n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits].
	// wb_cfg == [n_wrap_c1: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits].
assign cfg_o_data  = {fifo_dout[57+:7], cfg_i_data_r[114+:25], cfg_i_data_r[82+:32]}; // 64-bits
assign cfg_o_valid =
cfg_o_ready


assign ftm_n_lim  = cfg_i_data_r[139+:4];

// assign ftm_args 		 = cfg_data[146+:32]; // $r4
// assign ftm_n_wrap_c_sum	 = ftm_args[0+:7];
// assign ftm_n    		 = ftm_args[7+:4];

endmodule