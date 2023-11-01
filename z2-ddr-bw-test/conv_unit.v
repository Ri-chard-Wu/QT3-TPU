


// Requirement: 2 * pad + 1 == kernel size.
// Requirement: stride < N_FTMBUF_X.

module conv_unit
    #(
        parameter ID = 0,

        parameter N_DSP_GROUP = 4, 
        parameter N_KERNEL = 4,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,

        parameter B_PARA = 64,
        parameter B_SHAPE = 25,
        
        parameter N_FTMBUF_X = 5,
        parameter N_WEIBUF_X = 1,
            
        parameter B_BUF_ADDR = 9, 
        parameter DATA_WIDTH = 64,
        parameter B_COORD = 8,

        parameter N_CONV_UNIT = 8,

		parameter UNIT_BURSTS_WEI = 32,  // need to be power of 2.
		parameter UNIT_BURSTS_FTM = 1024  // need to be power of 2.	        
        
        
    )
    (

		output wire is_tail		              , 

        input  wire          pipe_en           ,
        input  wire          pipe_en_i         ,
        output wire          pipe_en_o         ,

        input wire                     clk    ,    
        input wire                     rstn    ,     
        
        // input wire [B_PARA-1:0]       para    ,
        // input wire                    para_we ,

        input wire                   wb_we    ,
        input wire                   wb_clr   ,
        output wire                  wb_empty ,
        output wire                  wb_suff  ,
        output wire                  wb_full  , 
		input wire    [31:0]		 wb_cfg   , 
        input wire                   fb_we    ,
        input wire                   fb_clr   ,
        output wire                  fb_empty ,
        output wire                  fb_suff  ,
        output wire                  fb_full  ,
        input wire    [31:0]		 fb_cfg   , 
        input wire [DATA_WIDTH-1:0]  di       ,


        input  wire [2*B_PIXEL*N_KERNEL-1:0] acc_i,
        input  wire [2*B_PIXEL*N_KERNEL-1:0] acc_o,
        output wire                          acc_o_valid,      

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o,
 
    );



wire [N_DSP_GROUP-1:0] is_tail_i;
reg  [N_DSP_GROUP-1:0] is_tail_r;

reg  [$clog2(N_KERNEL)-1:0] wb_we_sel;
wire [N_KERNEL-1:0]         wb_we_i;


// weight shape (c1: 12-bits, w: 2-bits, h: 2-bits, pad: 2-bits, stride: 2-bits).
localparam B_N_DSP_C = $clog2(N_CONV_UNIT << 2);
wire [1:0]           wei_stride ;
wire [1:0]           wei_pad    ;
wire [24:0]          wei_shape  ;
wire [11:0]          wei_c1;
wire [B_N_DSP_C-1:0] wei_c1_mod;
wire [B_N_DSP_C-1:0] wei_c1_mod_r;

// fm shape (c: 12-bits, w: 10-bits, h: 10-bits).
wire [24:0] ftm_shape  ;




wire [N_FTMBUF_X*DATA_WIDTH-1:0] fb_do_raw;
wire [DATA_WIDTH-1:0]            fb_do;
wire [3:0]                       fb_rd_sel;
wire [B_PIXEL-1:0]               fb_do_la [0:N_DSP_GROUP-1];

wire [DATA_WIDTH-1:0]            wb_do_i [0:N_KERNEL-1];
wire [B_PIXEL*N_KERNEL-1:0]      wb_do [0:N_DSP_GROUP-1];
wire [B_PIXEL*N_KERNEL-1:0]      wb_do_la [0:N_DSP_GROUP-1];

wire [2*B_PIXEL*N_KERNEL-1:0] acc_i_arr [0:N_DSP_GROUP-1];
wire [2*B_PIXEL*N_KERNEL-1:0] acc_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];


wire [B_BUF_ADDR*N_FTMBUF_X-1:0] fb_rd_addr ;
wire [B_BUF_ADDR-1:0]            wb_rd_addr [0:N_KERNEL-1];

wire [B_COORD-1:0] c_i [0:1];
wire [B_COORD-1:0] y_i [0:1];
wire [B_COORD-1:0] x_i [0:1];
wire [1:0] done_ld;

wire [N_KERNEL:0] wb_tog;
wire              fb_tog;

// reg [B_PARA-1:0] para_r;


integer i;

always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        state	<= INIT_ST;
        // para_r  <= 0;

        wb_we_sel    <= 0;
        wei_c1_mod_r <= 0;
        is_tail_r    <= 0;    
    end 
    else begin    

        // if(para_we) 
        //     para_r <= para;

        wei_c1_mod_r <= wei_c1_mod;
        is_tail_r    <= is_tail_i ;
    end
end    




generate
    if (ID == 4*(N_CONV_UNIT-1)) begin

        wire[7:0]                    n_wrap_c_lim;
        reg [7:0]                    n_wrap_c_r;
        reg [2*B_PIXEL*N_KERNEL-1:0] acc_r;
        reg [2*B_PIXEL*N_KERNEL-1:0] acc_o_r;
        reg [N_KERNEL-1:0]           acc_o_valid_r;
        reg [2*B_PIXEL*N_KERNEL-1:0] acc_o_r_la;
        reg [N_KERNEL-1:0]           acc_o_valid_r_la;

        always @( posedge clk ) begin

            if ( rstn == 1'b0 ) begin
                n_wrap_c_r       <= 0;
                acc_r            <= 0;
                acc_o_r          <= 0;    
                acc_o_valid_r    <= 0;    
                acc_o_r_la       <= 0;    
                acc_o_valid_r_la <= 0;                  
            end 
            else begin    

                if(pipe_en_o == 1'b1) begin
                    
                    for (i=0; i<N_KERNEL; i=i+1) begin

                        if(n_wrap_c_r[i] == n_wrap_c_lim)begin
                        
                            n_wrap_c_r                      <= 0;
                            acc_r                           <= 0;
                            acc_o_valid_r[i]                <= 1'b1;
                            acc_o_r[i*2*B_PIXEL+:2*B_PIXEL] <=  acc_r[i*2*B_PIXEL+:2*B_PIXEL] +
                                                            acc_o_arr[N_DSP_GROUP-1][i*2*B_PIXEL+:2*B_PIXEL];
                        end                    
                        else begin

                            n_wrap_c_r                    <= n_wrap_c_r + 1;
                            acc_o_valid_r[i]              <= 1'b0;
                            acc_r[i*2*B_PIXEL+:2*B_PIXEL] <= acc_r[i*2*B_PIXEL+:2*B_PIXEL] + 
                                                            acc_o_arr[N_DSP_GROUP-1][i*2*B_PIXEL+:2*B_PIXEL];
                        end
                    end
                end
            end
        end     

        assign n_wrap_c_lim = (wei_c1 >> $clog2(4*N_CONV_UNIT));


        generate
        genvar k;

            for (k=0; k < N_KERNEL; k=k+1) begin

                latency_reg
                    #(
                        .N(k), 
                        .B(2*B_PIXEL)
                    )
                    acc_o_latency_reg_i
                    (
                        .clk	(clk			),
                        .rstn	(rstn			),
                        .din	(acc_o_r   [k*2*B_PIXEL+:2*B_PIXEL]),
                        .dout	(acc_o_r_la[k*2*B_PIXEL+:2*B_PIXEL])
                    );

                latency_reg
                    #(
                        .N(k), 
                        .B(1)
                    )
                    acc_o_latency_reg_i
                    (
                        .clk	(clk			    ),
                        .rstn	(rstn			    ),
                        .din	(acc_o_valid_r   [k]),
                        .dout	(acc_o_valid_r_la[k])
                    );

            end
        endgenerate 

        assign acc_o       = acc_o_r_la;
        assign acc_o_valid = acc_o_valid_r_la[0]; 

    end
    else begin
        assign acc_o       = acc_o_arr[N_DSP_GROUP-1];
        assign acc_o_valid = 1'b0;
    end
endgenerate


// weight shape (n_wrap_c: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits).
assign wei_stride              = wb_cfg[1:0] ;
assign wei_pad                 = wb_cfg[3:2] ;

assign wei_shape[0+:9]         = wb_cfg[5:4] ; // w
assign wei_shape[9+:9]         = wb_cfg[7:6] ; // h
assign wei_shape[18+:7]        = wb_cfg[8+:7]; // n_wrap_c
assign wei_n_wrap_c_sum        = wb_cfg[8+:7]; // n_wrap_c

// assign wei_c1 = wei_shape[31:20];

// [n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits].
assign ftm_shape[0+:9]         = fb_cfg[0+:9] ; // w
assign ftm_shape[9+:9]         = fb_cfg[9+:9] ; // h
assign ftm_shape[18+:7]        = fb_cfg[25+:7]; // n_wrap_c (of each particular ftm).
assign ftm_n_wrap_c_sum        = fb_cfg[18+:7]; // n_wrap_c_sum


assign rd_en = (pipe_en == 1'b1) ? (ID == 0) ? 1'b1 : pipe_en_i
                                 : 1'b0;

// TODO: modify ftm_buffer_reader for new scheme: only read from 1 BRAM out of 10, instead of 3 form 5.
strided_buffer_reader
    #(
        .N_BUF_X    (N_FTMBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD),
        .N_CONV_UNIT(N_CONV_UNIT),
        .UNIT_BURSTS(UNIT_BURSTS_FTM)
    )
    ftm_buffer_reader_i
    (
        .clk  (clk	)	     ,    
        .rstn (rstn)         ,     
        
        .stride(wei_stride)   ,
        .pad   (wei_pad   )   ,

        .ftm_shape(ftm_shape),
        .wei_shape(wei_shape),

        .rd_en   (rd_en)         , // == 0 when pipeline halts.

        // TODO: fb_rd_addr and fb_rd_sel may not be synced, need add delay regs.
        .rd_addr  (fb_rd_addr)     ,        
        .rd_sel  (fb_rd_sel)     ,

        // output x, y coord to read, so we know whether to pad or not.
        // .tog      ( ),

        .is_last  (ftm_is_last ),

        .rptr_incr_en  (0),
        .rptr          ()
    );


strided_buffer
    #(
        .N_BUF_X    (N_FTMBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD),
        .UNIT_BURSTS(UNIT_BURSTS_WEI)
    )
    ftm_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)        ,     

        .shape        (ftm_shape       ),
        .n_wrap_c_sum (ftm_n_wrap_c_sum),

        .clr(fb_clr),
        
        .we(fb_we),
        .di(di),
        
        .rdaddr(fb_rd_addr),
        .do    (fb_do_raw), 
        

        .fb_wptr  (fb_wptr),
        .tog      (fb_tog ),
        // .full     (fb_full),
        .wptr     ()
    );




assign fb_suff = fb_tog;

// TODO: change to 10-to-1 mux.
assign fb_do = (0 == fb_rd_sel) ? fb_do_raw[0*DATA_WIDTH+:DATA_WIDTH] :
               (1 == fb_rd_sel) ? fb_do_raw[1*DATA_WIDTH+:DATA_WIDTH] :
               (2 == fb_rd_sel) ? fb_do_raw[2*DATA_WIDTH+:DATA_WIDTH] :
               (3 == fb_rd_sel) ? fb_do_raw[3*DATA_WIDTH+:DATA_WIDTH] :
               (4 == fb_rd_sel) ? fb_do_raw[4*DATA_WIDTH+:DATA_WIDTH] : 0; // 0: for padding.


wire [N_KERNEL-1:0] wb_full_i;

generate
genvar i, ii;

	for (i=0; i < N_KERNEL; i=i+1) begin

        strided_buffer_reader
            #(
                .N_BUF_X    (N_WEIBUF_X), 
                .B_BUF_ADDR (B_BUF_ADDR),
                .B_SHAPE   (B_SHAPE)  ,
                .DATA_WIDTH (DATA_WIDTH),
                .B_COORD    (B_COORD),
                .N_CONV_UNIT(N_CONV_UNIT)
            )
            wei_buffer_reader_i
            (
                .clk  (clk	)	    ,    
                .rstn (rstn)         ,     

                .stride(1   )   ,
                .pad   (0   )   ,

                .ftm_shape(wei_shape), // yes, wei_shape.
                .wei_shape(wei_shape),

                .rd_en   (rd_en)    ,  // == 0 when pipeline halts.
                
                .rd_addr  (wb_rd_addr[i]),
                .rd_sel(),

                // .tog     (),
                .is_last      (),

                .rptr_incr_en (ftm_is_last),
                .rptr         (wb_rptr[i])
            );




        strided_buffer
            #(
                .N_BUF_X    (N_WEIBUF_X), 
                .B_BUF_ADDR (B_BUF_ADDR),
                .B_SHAPE   (B_SHAPE)  ,
                .DATA_WIDTH (DATA_WIDTH),
                .B_COORD    (B_COORD)
            )
            wei_buffer
            (
                .clk  (clk	)	    ,    
                .rstn (rstn)         ,     

                .shape        (wei_shape),
                .n_wrap_c_sum (wei_n_wrap_c_sum ),

                .clr(wb_clr[i]),
                
                .we    (wb_we_i[i])              ,
                .di    (di)                 ,
                
                .rdaddr(wb_rd_addr[i])         ,
                .do    (wb_do_i[i])  ,

                .tog (wb_tog[i]),     // will toggle whenever one kernel is completly loaded.
                 
                // .full     (wb_full   ),
                .wptr     (wb_wptr[i])                   
            );

        assign wb_we_i[i] = (i == 0) ? (wb_tog[0] == wb_tog[N_KERNEL-1]) ? wb_we : 1'b0 :
                                       (wb_tog[i-1] ^ wb_tog[i])         ? wb_we : 1'b0;

        for (ii=0; ii < N_DSP_GROUP; ii=ii+1) begin

            assign wb_do[ii][i*B_PIXEL+:B_PIXEL] = wb_do_i[i][ii*B_PIXEL+:B_PIXEL];
        end
      

        assign wb_full_i[i] = (wb_wptr[i] > wb_rptr[i]) ? 
                (N_BUF_ENTRIES + wb_rptr[i] - wb_wptr[i] < UNIT_BURSTS) ? 1'b1: 1'b0 : // wraddr > rdaddr
                (                wb_rptr[i] - wb_wptr[i] < UNIT_BURSTS) ? 1'b1: 1'b0 ; // wraddr <= rdaddr

	end
endgenerate 


assign wb_full = |wb_full_i;

assign wb_suff = wb_tog[N_KERNEL-1];



latency_reg
    #(
        .N(N_DSP_GROUP + 3 + 1), // latency. 3(?): DSP's latency. 1(?): buffer read latency.
        .B(1)
    )
    pipe_en_latency_reg_i
    (
        .clk	(clk			),
        .rstn	(rstn			),

        .din	(pipe_en_i),
        .dout	(pipe_en_o)
    );

    

generate
genvar j;

	for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP

		latency_reg
			#(
				.N(j), // latency.
				.B(B_PIXEL)
			)
			fb_latency_reg_i
			(
                .clk	(clk			),
				.rstn	(rstn			),
		
				.din	(fb_do[j*B_PIXEL+:B_PIXEL]	),
				.dout	(fb_do_la[j]	)
			);

		latency_reg
			#(
				.N(j), // latency.
				.B(B_PIXEL*N_KERNEL)
			)
			wb_latency_reg_i
			(
                .clk	(clk			),
				.rstn	(rstn			),
		
				.din	(wb_do[j]	),
				.dout	(wb_do_la[j]	)
			);


        dsp_group 
            #(
                .N_DSP(N_KERNEL)
            )
            dsp_group_i
            (
                .clk 		   (clk                 ),
                .rstn		   (rstn                ),

                .inst_i        (inst_i_arr[j]       ),
                .inst_o        (inst_o_arr[j]       ),

                .wei_i         (wb_do_la[j]    ),
                .ftm_i         (fb_do_la[j]    ),

                .acc_i (acc_i_arr[j]),
                .acc_o    (acc_o_arr[j])
            );

        assign is_tail_i[i] = (ID + j == wei_c1_mod_r) ? 1'b1 : 1'b0;
 
        assign acc_i_arr[j] = (j==0) ? acc_i: acc_o_arr[j-1];
        assign inst_i_arr[j] = (j==0) ? inst_i: inst_o_arr[j-1];


   
        // assign acc_next = (is_tail_i[i] == 1'b1) ? acc_o_arr[j] : 0;
       
	end
endgenerate 


assign is_tail = |is_tail_r;

// (c1 - 1) % (4 * N_CONV_UNIT).
assign wei_c1_mod = wei_c1[B_N_DSP_C-1:0] - 1; // TODO: check whether 5'b00000 - 1 == 5'b11111.


assign inst_o = inst_o_arr[N_DSP_GROUP-1];

assign fb_empty = (fb_rptr == fb_wptr);

endmodule