



module conv_unit
    #(
        parameter N_DSP_GROUP = 4, 
        parameter N_KERNEL = 4,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,

        parameter B_PARA = 64,
        parameter B_SHAPE = 32,

        parameter N_FTMBUF_X = 5,
        parameter N_WEIBUF_X = 1,
            
        parameter B_BUF_ADDR = 9, 
        parameter DATA_WIDTH = 64,
        parameter B_COORD = 8
    )
    (
        input wire                     clk		    ,    
        input wire                     rstn         ,     
        
        input wire [B_PARA-1:0]       para    ,
        input wire                    para_we ,

        output wire fb_sufficient              ,
        output wire fb_full                    ,
        output wire wb_sufficient              ,
        output wire wb_full                    ,
            

        input wire                   fb_we    ,
        input wire                   fb_clr   ,
        output wire                  fb_empty ,

        // input wire   [N_KERNEL-1:0]  wb_we    ,
        // input wire   [N_KERNEL-1:0]  wb_clr   ,
        input wire                   wb_we    ,
        input wire                   wb_clr   ,

        output wire                  wb_empty ,
        input wire [DATA_WIDTH-1:0]  di    ,


        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o,

 
        output wire [15:0]       res
    );





reg  [$clog2(N_KERNEL)-1:0] wb_we_sel;
wire [N_KERNEL-1:0]         wb_we_i;


// weight shape (c1: 12-bits, w: 2-bits, h: 2-bits, pad: 2-bits, stride: 2-bits).
wire [1:0]  wei_stride ;
wire [1:0]  wei_pad    ;
wire [31:0] wei_shape  ;

// fm shape (c: 12-bits, w: 10-bits, h: 10-bits).
wire [31:0] ftm_shape  ;


wire [DATA_WIDTH-1:0] fb_do;
wire [DATA_WIDTH-1:0] wb_do_k [0:N_KERNEL-1];
wire [B_PIXEL*3-1:0]  wb_do_g [0:N_DSP_GROUP-1];


wire [B_PIXEL-1:0] partial_sum_i_arr [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] partial_sum_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];


wire [B_BUF_ADDR*N_FTMBUF_X-1:0] fb_rdaddr ;
wire [B_BUF_ADDR-1:0]            wb_rdaddr [0:N_KERNEL-1];

wire [3*B_COORD-1:0] cur_coord [0:1];
wire [B_COORD-1:0] c_i [0:1];
wire [B_COORD-1:0] y_i [0:1];
wire [B_COORD-1:0] x_i [0:1];
wire [1:0] done_ld;

// States.
localparam	INIT_ST		       = 0;
localparam	LOAD_LAYERPARA_ST  = 1;
localparam	COMPUTE_ST   	   = 2;

reg			init_state;
reg			compute_state;



reg [B_PARA-1:0] para_r;

integer i;



always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        state	<= INIT_ST;
        para_r  <= 0;

        wb_we_sel <= 0;
    end 
    else begin    

		case(state)

			INIT_ST:
                if (x_i[0] >= 3 && done_ld[1])
                    state <= COMPUTE_ST;
	
            COMPUTE_ST:
                if()

		endcase	

        if(para_we) 
            para_r <= para;
    end
end    



// weight shape (c1: 12-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits).
assign wei_stride = para_r[1:0] ;
assign wei_pad    = para_r[3:2] ;
assign wei_shape[9:0]        = para_r[5:4] ;
assign wei_shape[19:10]      = para_r[7:6] ;
assign wei_shape[31:20]      = para_r[19:8];

// fm shape (c: 12-bits, h: 10-bits, w: 10-bits).
assign ftm_shape[9:0]        = para_r[9:0]  ;
assign ftm_shape[19:10]      = para_r[19:10];
assign ftm_shape[31:20]      = para_r[31:20];


// FSM outputs.
always @(state) begin

    init_state	        = 0;
    compute_state	    = 0;

	case (state)

		INIT_ST:
			init_state       	= 1;

        COMPUTE_ST:
            compute_state       = 1;
	endcase
end




wire   [3:0] fb_rd_sel;
wire [N_FTMBUF_X*DATA_WIDTH-1:0] fb_do_raw;

ftm_buffer_reader
    #(
        .N_BUF_X    (N_FTMBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    ftm_buffer_reader_i
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     
        
        .ftm_shape(ftm_shape),
        .wei_shape(wei_shape),

        .start   (start)         ,
        .rdaddr  (fb_rdaddr)     ,        
        .rd_sel  (fb_rd_sel)     ,

        .fb_rptr  (fb_rptr)
    );




strided_buffer
    #(
        .N_BUF_X    (N_FTMBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    ftm_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .shape (ftm_shape),

        .clr(fb_clr),
        
        .we(fb_we),
        .di(di),
        
        .rdaddr(fb_rdaddr),
        .do    (fb_do_raw), 
        

        .fb_wptr  (fb_wptr),
        .sufficient (fb_sufficient)
        // .cur_coord(cur_coord[0]), 
        // .done_ld(done_ld[0])
    );



assign fb_do = (0 == fb_rd_sel) ? fb_do_raw[0*DATA_WIDTH+:DATA_WIDTH] :
               (1 == fb_rd_sel) ? fb_do_raw[1*DATA_WIDTH+:DATA_WIDTH] :
               (2 == fb_rd_sel) ? fb_do_raw[2*DATA_WIDTH+:DATA_WIDTH] :
               (3 == fb_rd_sel) ? fb_do_raw[3*DATA_WIDTH+:DATA_WIDTH] :
               (4 == fb_rd_sel) ? fb_do_raw[4*DATA_WIDTH+:DATA_WIDTH] : 0;



wire [N_KERNEL:0] wb_sufficient;

generate
genvar i;

	for (i=0; i < N_KERNEL; i=i+1) begin : GEN_DSP_GROUP

        wei_buffer_reader
            #(
                .N_BUF_X    (N_WEIBUF_X), 
                .B_BUF_ADDR (B_BUF_ADDR),
                .B_SHAPE   (B_SHAPE)  ,
                .DATA_WIDTH (DATA_WIDTH),
                .B_COORD    (B_COORD)
            )
            wei_buffer_reader_i
            (
                .clk  (clk	)	    ,    
                .rstn (rstn)         ,     

                .wei_shape(wei_shape),

                .start   (start)    ,
                .rdaddr  (wb_rdaddr[i])
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

                .shape (wei_shape),

                .clr(wb_clr[i]),
                
                .we    (wb_we_i[i])              ,
                .di    (di)                 ,
                
                .rdaddr(wb_rdaddr[i])         ,
                .do    (wb_do_k[i])  ,

                .tog (wb_tog[i])     // will toggle whenever one kernel is completly loaded.       

                // .cur_coord(cur_coord[1]),
                // .done_ld(done_ld[1])
            );

        assign wb_we_i[i] = (i == 0) ? (wb_tog[0] == wb_tog[N_KERNEL-1]) ? wb_we : 1'b0 :
                                       (wb_tog[i-1] ^ wb_tog[i])         ? wb_we : 1'b0;
	end
endgenerate 



assign c_i[0] = cur_coord[0][0*B_COORD+:B_COORD];
assign y_i[0] = cur_coord[0][1*B_COORD+:B_COORD];
assign x_i[0] = cur_coord[0][2*B_COORD+:B_COORD];

assign c_i[1] = cur_coord[1][0*B_COORD+:B_COORD];
assign y_i[1] = cur_coord[1][1*B_COORD+:B_COORD];
assign x_i[1] = cur_coord[1][2*B_COORD+:B_COORD];



generate
genvar j;

	for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP
 
        assign wb_do_g[j] = {wb_do_k[0][j*DATA_WIDTH+:DATA_WIDTH], 
                             wb_do_k[1][j*DATA_WIDTH+:DATA_WIDTH], 
                             wb_do_k[2][j*DATA_WIDTH+:DATA_WIDTH]}
        
        assign partial_sum_i_arr[j] = (j==0) ? partial_sum_i: partial_sum_o_arr[j-1];
        assign inst_i_arr[j] = (j==0) ? inst_i: inst_o_arr[j-1];

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

                .wei_i         (fb_do[j*DATA_WIDTH+:DATA_WIDTH]     ),
                .ftm_i         (wb_do_g[j]),

                .partial_sum_i (partial_sum_i_arr[j]),
                .partial_sum_o (partial_sum_o_arr[j])
            );

	end
endgenerate 

assign partial_sum_o = partial_sum_o_arr[N_DSP_GROUP-1];
assign inst_o = inst_o_arr[N_DSP_GROUP-1];


assign fb_empty = (fb_rptr == fb_wptr);

endmodule