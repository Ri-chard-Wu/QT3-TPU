module ddr_reader
    #(
        parameter N_KERNEL = 4, 
        parameter B_PIXEL = 16,
        parameter DATA_WIDTH = 64,
        parameter ADDR_WIDTH = 32	,
        parameter N_DSP_GROUP = 4		
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input  wire					 m_axis_tvalid,
        input  wire	[DATA_WIDTH-1:0] m_axis_tdata ,
        output wire					 m_axis_tready,


        input wire                      wb_sufficient,
        input wire    [N_CONV_UNIT-1:0] wb_full      ,          
        input wire    [N_CONV_UNIT-1:0] fb_sufficient, // not needed?
        input wire    [N_CONV_UNIT-1:0] fb_full      ,   

        output wire   [N_CONV_UNIT-1:0]  wb_we    ,
        output wire   [N_CONV_UNIT-1:0]  wb_clr   ,
        input  wire   [N_CONV_UNIT-1:0]  wb_empty ,
        output wire   [N_CONV_UNIT-1:0]  fb_we    ,
        output wire   [N_CONV_UNIT-1:0]  fb_clr   ,
        input  wire   [N_CONV_UNIT-1:0]  fb_empty ,
        output wire   [DATA_WIDTH-1:0]   mem_di   ,

        output wire   [63:0]             conv_para   ,
        output wire 		             conv_para_we,

        input  wire                      cfg_valid,
        input  wire [FW-1:0]             cfg_data ,
        output wire 		             cfg_ready,

        input wire			             RSTART_REG	,
        input wire	[31:0]	             RADDR_REG	,
        input wire	[31:0]	             RNBURST_REG,
        input wire                       RDONE_REG   

                        
    );



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

wire [31:0] wei_addr 		    ;
wire [6:0]  wei_n_last_burst    ;
wire [24:0] wei_n_rema_bursts   ;

wire [31:0] ftm_addr 	  	    ;
wire [6:0]  ftm_n_last_burst    ;
wire [24:0] ftm_n_rema_bursts   ;


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


    
wire wb_done_i ;          
wire fb_done_i ;    
  


assign oper	             = cfg_data[28:11]; // 18-bits.

assign wei_addr 		 = cfg_data[31:0];
assign wei_n_last_burst  = cfg_data[38:32]; // number of valid bytes in last burst.
assign wei_n_rema_bursts = cfg_data[63:39]; // each burst is 128 bytes (16 * 64-bits).

assign ftm_addr 	  	 = cfg_data[95:64];
assign ftm_n_last_burst  = cfg_data[102:96];
assign ftm_n_rema_bursts = cfg_data[127:103];

assign conv_para         = cfg_data_i[191:128];


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

    end 
    else begin    


		// load wei until sufficient -> load fm until done -> load wei until done -> pre-load next layer.
		case(state)

			INIT_ST:
                if (cfg_valid == 0)
                    state <= WEI_INIT_ST;
			
			WEI_INIT_ST:
				state <= WEI_LOAD_ST;

			WEI_INCR_ST:
				if(~wb_full_i)
					state <= WEI_LOAD_ST;

			WEI_LOAD_ST:
				if (RDONE_REG) begin // When mst_read in END state.
					if (wb_sufficient && ~fb_done_i) 
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


assign wei_pending_i = (wei_cnt_r == wei_cnt_incr_r) ? 0 : 1;
assign ftm_pending_i = (ftm_cnt_r == ftm_cnt_incr_r) ? 0 : 1;


assign cfg_ready = init_st;

assign cu_sel_i = wei_pending_i ? wei_cu_sel : 
				  ftm_pending_i ? ftm_cu_sel : 0;


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


assign conv_para_we = cfg_valid & init_st;

endmodule