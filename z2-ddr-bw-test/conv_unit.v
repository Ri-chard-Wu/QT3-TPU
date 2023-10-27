



module conv_unit
    #(
        parameter N_DSP_GROUP = 4, 
        parameter N_KERNEL = 3,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,
        parameter B_LAYERPARA = 96,

        parameter N_WEIBUF_X = 5,
        parameter N_KERBUF_X = 1,
        parameter B_SHAPE = 48,
    
        parameter B_BUF_ADDR = 9, 
        parameter DATA_WIDTH = 64,
        parameter B_COORD = 8
    )
    (
        input wire                     clk		    ,    
        input wire                     rstn         ,     

        input wire [B_LAYERPARA-1:0]   layer_para    ,
        input wire                     layer_para_we ,


        input wire                   wb_we    ,
        input wire                   wb_clr   ,
        output wire                  wb_empty ,
        input wire   [N_KERNEL-1:0]  kb_we    ,
        input wire   [N_KERNEL-1:0]  kb_clr   ,
        output wire                  kb_empty ,
        input wire [DATA_WIDTH-1:0]  di    ,


        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o,

 
        output wire [15:0]       res
    );




wire [DATA_WIDTH-1:0] wb_do;
wire [DATA_WIDTH-1:0] kb_do_k [0:N_KERNEL-1];
wire [B_PIXEL*3-1:0]  kb_do_g [0:N_DSP_GROUP-1];


wire [B_PIXEL-1:0] partial_sum_i_arr [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] partial_sum_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];




wire [B_BUF_ADDR*N_WEIBUF_X-1:0] wb_rdaddr ;
wire [B_BUF_ADDR-1:0]            kb_rdaddr [0:N_KERNEL-1];

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


reg [B_LAYERPARA-1:0] layer_para_r;

integer i;



always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        state	<= INIT_ST;

        layer_para_r <= 0;


    end 
    else begin    

		case(state)

			INIT_ST:
                if (x_i[0] >= 3 && done_ld[1])
                    state <= COMPUTE_ST;
	
            COMPUTE_ST:
                if()

		endcase	

        if(layer_para_we)
            layer_para_r <= layer_para;

  
      
    end
end    



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




wire   [3:0] wb_rd_sel;
wire [N_WEIBUF_X*DATA_WIDTH-1:0] wb_do_raw;

weight_buffer_reader
    #(
        .N_BUF_X    (N_WEIBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    weight_buffer_reader_i
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .wei_shape(layer_para_r[0*B_SHAPE+:B_SHAPE]),
        .ker_shape(layer_para_r[1*B_SHAPE+:B_SHAPE]),

        .start   (start)         ,
        .rdaddr  (wb_rdaddr)     ,        
        .rd_sel  (wb_rd_sel)     ,

        .wb_rptr  (wb_rptr)
    );




strided_buffer
    #(
        .N_BUF_X    (N_WEIBUF_X), 
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_SHAPE   (B_SHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    weight_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .shape (layer_para_r[0*B_SHAPE+:B_SHAPE]),

        .clr(wb_clr),
        
        .we(wb_we),
        .di(di),
        
        .rdaddr(wb_rdaddr),
        .do    (wb_do_raw), 
        

        .wb_wptr  (wb_wptr)
        // .cur_coord(cur_coord[0]), 
        // .done_ld(done_ld[0])
    );



assign wb_do = (0 == wb_rd_sel) ? wb_do_raw[0*DATA_WIDTH+:DATA_WIDTH] :
               (1 == wb_rd_sel) ? wb_do_raw[1*DATA_WIDTH+:DATA_WIDTH] :
               (2 == wb_rd_sel) ? wb_do_raw[2*DATA_WIDTH+:DATA_WIDTH] :
               (3 == wb_rd_sel) ? wb_do_raw[3*DATA_WIDTH+:DATA_WIDTH] :
               (4 == wb_rd_sel) ? wb_do_raw[4*DATA_WIDTH+:DATA_WIDTH] : 0;







generate
genvar i;

	for (i=0; i < N_KERNEL; i=i+1) begin : GEN_DSP_GROUP


        kernel_buffer_reader
            #(
                .N_BUF_X    (N_KERBUF_X), 
                .B_BUF_ADDR (B_BUF_ADDR),
                .B_SHAPE   (B_SHAPE)  ,
                .DATA_WIDTH (DATA_WIDTH),
                .B_COORD    (B_COORD)
            )
            kernel_buffer_reader_i
            (
                .clk  (clk	)	    ,    
                .rstn (rstn)         ,     

                .ker_shape(layer_para_r[1*B_SHAPE+:B_SHAPE]),

                .start   (start)    ,
                .rdaddr  (kb_rdaddr[i])
            );



            
        strided_buffer
            #(
                .N_BUF_X    (N_KERBUF_X), 
                .B_BUF_ADDR (B_BUF_ADDR),
                .B_SHAPE   (B_SHAPE)  ,
                .DATA_WIDTH (DATA_WIDTH),
                .B_COORD    (B_COORD)
            )
            kernel_buffer
            (
                .clk  (clk	)	    ,    
                .rstn (rstn)         ,     

                .shape (layer_para_r[1*B_SHAPE+:B_SHAPE]),

                .clr(kb_clr[i]),
                
                .we(kb_we[i])              ,
                .di(di)                 ,
                

                .rdaddr(kb_rdaddr[i])         ,
                .do    (kb_do_k[i])              

                // .cur_coord(cur_coord[1]),
                // .done_ld(done_ld[1])
            );


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
 
        assign kb_do_g[j] = {kb_do_k[0][j*DATA_WIDTH+:DATA_WIDTH], 
                             kb_do_k[1][j*DATA_WIDTH+:DATA_WIDTH], 
                             kb_do_k[2][j*DATA_WIDTH+:DATA_WIDTH]}
        
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

                .wei_i         (wb_do[j*DATA_WIDTH+:DATA_WIDTH]     ),
                .ker_i         (kb_do_g[j]),

                .partial_sum_i (partial_sum_i_arr[j]),
                .partial_sum_o (partial_sum_o_arr[j])
            );

	end
endgenerate 

assign partial_sum_o = partial_sum_o_arr[N_DSP_GROUP-1];
assign inst_o = inst_o_arr[N_DSP_GROUP-1];


assign wb_empty = (wb_rptr == wb_wptr);

endmodule