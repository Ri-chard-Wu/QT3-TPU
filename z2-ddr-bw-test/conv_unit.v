



module conv_unit
    #(
        parameter N_DSP_GROUP = 4, 
        parameter N_DSP = 3,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,
        parameter B_LAYERPARA = 96,

        parameter N_WEIBUF_X = 5,
        parameter N_KERBUF_X = 3,
        parameter B_DSHAPE = 48,
    
        parameter B_BUF_ADDR = 9, 
        parameter DATA_WIDTH = 64,
        parameter B_COORD = 8
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire [B_LAYERPARA-1:0]   layer_para       ,
        input wire                     layer_para_we ,


        input wire                  wb_we,
        input wire                  wb_clr,
        input wire                  kb_we,
        input wire                  kb_clr,
        input wire [DATA_WIDTH-1:0] di,


        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o

        // input wire               WSTART_REG ,
        // input wire               RSTART_REG, 
        
        // output wire [15:0]       res
    );



wire [2*B_COORD-1:0] rd_coord [0:1];

wire [DATA_WIDTH * N_WEIBUF_X-1:0] wb_do;
wire [DATA_WIDTH * N_KERBUF_X-1:0] kb_do;

reg  [2:0] wb_rd_sel [0:N_DSP-1];
reg  [2:0] kb_rd_sel [0:N_DSP-1];


wire [B_PIXEL-1:0] partial_sum_i_arr [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] partial_sum_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];

wire [B_PIXEL*3-1:0] wei_i [0:N_DSP_GROUP-1];
wire [B_PIXEL*3-1:0] ker_i [0:N_DSP_GROUP-1];

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

        for (i=0; i<N_DSP; i=i+1)begin
            wb_rd_sel[i] <= i[2:0];
            kb_rd_sel[i] <= i[2:0];
        end

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

        for (i=0; i<N_DSP; i=i+1) begin

            if (kb_rd_sel[i] == N_KERBUF_X - 1)    
                kb_rd_sel[i] <= 0;
            else 
                kb_rd_sel[i] <= kb_rd_sel[i] + 1;
        end
      
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




strided_buffer
    #(
        .N_BUF_X    (N_WEIBUF_X), 
        .N_DSP      (N_DSP)     ,
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_DSHAPE   (B_DSHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    weight_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .dshape (layer_para_r[0*B_DSHAPE+:B_DSHAPE]),

        .clr(wb_clr),
        
        .we(wb_we),
        .di(di),
        

        .rd_coord(rd_coord[0]),
        .do(wb_do), 
        
        .cur_coord(cur_coord[0]), 
        .done_ld(done_ld[0])
    );





strided_buffer
    #(
        .N_BUF_X    (N_KERBUF_X), 
        .N_DSP      (N_DSP)     ,
        .B_BUF_ADDR (B_BUF_ADDR),
        .B_DSHAPE   (B_DSHAPE)  ,
        .DATA_WIDTH (DATA_WIDTH),
        .B_COORD    (B_COORD)
    )
    kernel_buffer
    (
        .clk  (clk	)	    ,    
        .rstn (rstn)         ,     

        .dshape (layer_para_r[1*B_DSHAPE+:B_DSHAPE]),

        .clr(kb_clr),
        
        .we(kb_we)              ,
        .di(di)                 ,
        

        .rd_coord(rd_coord[1])         ,
        .do(kb_do)              , 

        .cur_coord(cur_coord[1]),
        .done_ld(done_ld[1])
    );



assign c_i[0] = cur_coord[0][0*B_COORD+:B_COORD];
assign y_i[0] = cur_coord[0][1*B_COORD+:B_COORD];
assign x_i[0] = cur_coord[0][2*B_COORD+:B_COORD];

assign c_i[1] = cur_coord[1][0*B_COORD+:B_COORD];
assign y_i[1] = cur_coord[1][1*B_COORD+:B_COORD];
assign x_i[1] = cur_coord[1][2*B_COORD+:B_COORD];




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