



module conv_unit
    #(
        parameter N_WEIGHT_BUF = 5, 
        parameter N_KERNEL_BUF = 3, 
        parameter N_DSP_GROUP = 4, 
        parameter N_DSP = 3,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,
        parameter B_LAYERPARA = 80,

        parameter N_WEIBUF_X = 5,
        parameter N_KERBUF_X = 3,
        parameter B_DSHAPE = 48,
    
        parameter B_BUF_ADDR = 9, 
        parameter B_BUF_DATA = 64, 
        parameter DATA_WIDTH = 64
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire [B_LAYERPARA-1:0]   layer_para       ,
        input wire                     layer_para_we ,


        input wire                  wb_en,
        input wire                  wb_clr,
        input wire                  kb_en,
        input wire                  kb_clr,


        input wire [DATA_WIDTH-1:0] mem_di,

        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o

        // input wire               WSTART_REG ,
        // input wire               RSTART_REG, 
        
        // output wire [15:0]       res
    );



reg kb_en_r ;
reg kb_clr_r;



wire [N_KERNEL_BUF-1:0]        kb_we;

wire [B_BUF_ADDR-1:0]   wb_rdaddr [0:N_WEIGHT_BUF-1];
wire [B_BUF_ADDR-1:0]   kb_rdaddr [0:N_KERNEL_BUF-1];

wire [DATA_WIDTH*N_WEIBUF_X-1:0] wb_do;

wire [DATA_WIDTH-1:0] kb_do       [0:N_KERNEL_BUF-1];

reg [B_BUF_ADDR-1:0]   wb_wraddr [0:N_WEIGHT_BUF-1];
reg [B_BUF_ADDR-1:0]   kb_wraddr [0:N_KERNEL_BUF-1];


reg  [2:0] kb_wr_sel;
reg  [2:0] wb_rd_sel [0:N_DSP-1];
reg  [2:0] kb_rd_sel [0:N_DSP-1];



reg  [15:0]              kb_cnt_r;
wire [15:0]              kb_cnt;



wire [B_PIXEL-1:0] partial_sum_i_arr [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] partial_sum_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];

wire [B_PIXEL*3-1:0] wei_i [0:N_DSP_GROUP-1];
wire [B_PIXEL*3-1:0] ker_i [0:N_DSP_GROUP-1];




// States.
localparam	INIT_ST		       = 0;
localparam	LOAD_LAYERPARA_ST  = 1;
localparam	COMPUTE_ST   	   = 2;

reg			init_state;
reg			compute_state;


reg [B_LAYERPARA-1:0] layer_para_r;


wire [15:0] c_wei;
wire [15:0] h_wei;
wire [15:0] w_wei;
wire [15:0] k_ker;
wire [15:0] c_ker;


integer i;








strided_buffer
    #(
        .N_BUF_X    (N_WEIBUF_X), 
        .N_DSP      (N_DSP)     ,
        .B_DSHAPE   (B_DSHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH)
    )
    weight_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .dshape (layer_para_r[0*B_DSHAPE+:B_DSHAPE]),

        .clr(wb_clr),
        
        .en(wb_en),
        .di(mem_di),
        

        input wire [] rdaddr,
        .do(wb_do)
    );





strided_buffer
    #(
        .N_BUF_X    (N_KERBUF_X), 
        .N_DSP      (N_DSP)     ,
        .B_DSHAPE   (B_DSHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH)
    )
    kernel_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .dshape (layer_para_r[1*B_DSHAPE+:B_DSHAPE]),

        .clr(kb_clr),
        
        .en(kb_en),
        .di(mem_di),
        

        input wire [] rdaddr,
        .do(kb_do)
    );





always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        state	<= INIT_ST;

    
        for (i=0; i<N_KERNEL_BUF; i=i+1) kb_wraddr[i] <= 0;
        
    
        layer_para_r <= 0;

        kb_cnt_r   <= 0;

        kb_wr_sel <= 0;
        
        for (i=0; i<N_DSP; i=i+1)begin
            wb_rd_sel[i] <= i[2:0];
            kb_rd_sel[i] <= i[2:0];
        end


    end 
    else begin    

		case(state)

			INIT_ST:
                if ()
                    state <= COMPUTE_ST;
	
            COMPUTE_ST:


		endcase	



        kb_en_r <= kb_en;
        kb_clr_r <= kb_clr;

        if(layer_para_we)
            layer_para_r <= layer_para;




        if (kb_clr_r == 1'b1)
            kb_wr_sel <= 0;
        else if (wb_en_r) begin

            for (i=0; i<N_KERNEL_BUF; i=i+1) kb_wraddr[i] <= kb_wraddr[i] + kb_we[i];

            if(kb_cnt == kb_n_eps)

                kb_cnt_r <= 0;

               

                if(kb_wr_sel == N_KERNEL_BUF - 1)
                    kb_wr_sel <= 0;
                else
                    kb_wr_sel <= kb_wr_sel + 1;
            

            else
                kb_cnt_r <= kb_cnt;
        end


    

        for (i=0; i<N_DSP; i=i+1) begin

            if (kb_rd_sel[i] == N_KERNEL_BUF - 1)    
                kb_rd_sel[i] <= 0;
            else 
                kb_rd_sel[i] <= kb_rd_sel[i] + 1;
        end
      
    end
end    


assign c_ker = layer_para_r  [3*16+:16];
assign k_ker = layer_para_r  [4*16+:16]; // assume square.

// eps: entries per slice.
assign kb_n_eps = (c_ker >> 6) * k_ker;


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




// strided write.
generate
genvar k;
	for (k=0; k < N_KERNEL_BUF; k=k+1) begin : GEN_KERNEL_BUF

        // wrapper for BRAM primitives.
        bram_sdp #(
                .B_ADDR(B_BUF_ADDR),
                .B_DATA(B_BUF_DATA)
        	)
        	kernel_buffer_i
        	(
        		.clk		    (clk		),
        		.rstn         	(rstn		),

                .rdaddr     (kb_rdaddr[k]             ),
                .do         (kb_do[k]             ) ,

                .we         (kb_we[k] ),
                .wraddr     (kb_wraddr[k]             ),
                .di         (mem_di_r             )
                               
        	);

        assign kb_we[k] = kb_en_r & ((kb_wr_sel == k) ? 1'b1: 1'b0);

	end
endgenerate 

assign kb_cnt = kb_cnt_r + 1;









generate
genvar j;

	for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP

        assign wei_i[j]  = { wb_do[kb_rd_sel[0]*DATA_WIDTH + j*16 +: 16], 
                             wb_do[kb_rd_sel[1]*DATA_WIDTH + j*16 +: 16], 
                             wb_do[kb_rd_sel[2]*DATA_WIDTH + j*16 +: 16]};

        assign ker_i[j]  = { kb_do[kb_rd_sel[0]*DATA_WIDTH + j*16 +: 16], 
                             kb_do[kb_rd_sel[1]*DATA_WIDTH + j*16 +: 16], 
                             kb_do[kb_rd_sel[2]*DATA_WIDTH + j*16 +: 16]};

        assign partial_sum_i_arr[j] = (j==0) ? partial_sum_i: partial_sum_o_arr[j-1];
        assign inst_i_arr[j] = (j==0) ? inst_i: inst_o_arr[j-1];

        dsp_group 
            #(
    
            )
            dsp_group_i
            (
                .clk 		   (clk                 ),
                .rstn		   (rstn                ),

             
                .inst_i        (inst_i_arr[j]       ),
                .inst_o        (inst_o_arr[j]       ),

                .wei_i         (wei_i[j]     ),
                .ker_i         (ker_i[j]),

                .partial_sum_i (partial_sum_i_arr[j]),
                .partial_sum_o (partial_sum_o_arr[j])
            );

	end
endgenerate 

assign partial_sum_o = partial_sum_o_arr[N_DSP_GROUP-1];
assign inst_o = inst_o_arr[N_DSP_GROUP-1];




endmodule