



module conv_unit
    #(
        parameter N_BUF = 5, 
        parameter N_DSP_GROUP = 4, 
        parameter N_DSP = 3,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,
    
        parameter B_BUF_ADDR = 9, 
        parameter B_BUF_DATA = 64, 
        parameter DATA_WIDTH = 64
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire [31:0]        layer_para       ,
        input wire               layer_para_we ,


        input wire                  weigth_mem_en,
        input wire                  weight_mem_clr,
        input wire                  kernel_mem_en,
        input wire [DATA_WIDTH-1:0] mem_di,

        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [B_INST-1:0] inst_i,
        input wire [B_INST-1:0] inst_o

        // input wire               WSTART_REG ,
        // input wire               RSTART_REG, 
        
        // output wire [15:0]       res
    );



reg  weigth_mem_en_r;
reg  weight_mem_clr_r;
reg  [DATA_WIDTH-1:0] mem_di_r;


wire [DATA_WIDTH-1:0] mem_do       [0:N_BUF-1];
wire [N_BUF-1:0]        mem_we;

wire [B_BUF_ADDR-1:0]   rdaddr [0:N_BUF-1];
reg [B_BUF_ADDR-1:0]   wraddr [0:N_BUF-1];

reg  [7:0]              weight_sel_r;
reg  [7:0]              kernel_sel_r;
reg  [15:0]              load_cnt_r;
wire [15:0]              load_cnt;


reg  [7:0]              rd_sel_r;

wire [B_PIXEL-1:0] partial_sum_i_arr [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] partial_sum_o_arr [0:N_DSP_GROUP-1];

wire [B_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [B_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];

wire [B_PIXEL*3-1:0] dsp_group_di [0:N_DSP_GROUP-1];




// States.
localparam	INIT_ST		       = 0;
localparam	LOAD_LAYERPARA_ST  = 1;
localparam	LOAD_KERNEL_ST	   = 2;
localparam	COMPUTE_ST   	   = 3;

reg			init_state;
reg			load_layerpara_state;
reg			load_kernel_state;
reg			compute_state;


reg [31:0] layer_para_r;
wire [15:0] h_img;




always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        state	<= INIT_ST;

    
        for (i=0; i<N_BUF; i=i+1) wraddr[i] <= 0;
        
        weigth_mem_en_r <= 0;
        weight_mem_clr_r <= 0;
        mem_di_r        <= 0;

        layer_para_r <= 0;

        load_cnt_r   <= 0;
        weight_sel_r <= 0;
        kernel_sel_r <= 0;
        rd_sel_r <= 0;
    end 
    else begin    

		case(state)
			INIT_ST:
            
                if (layer_para_we == 1'b1) 
                    state <= LOAD_LAYERPARA_ST;
                else if (kernel_mem_en == 1'b1)
                    state <= LOAD_KERNEL_ST;

            LOAD_LAYERPARA_ST:
                state <= INIT_ST;

            LOAD_KERNEL_ST:
                if(kernel_mem_en == 1'b0)
                    state <= INIT_ST;				
	
            COMPUTE_ST:

		endcase	


        mem_di_r         <= mem_di;
        weigth_mem_en_r  <= weigth_mem_en;
        weight_mem_clr_r <= weight_mem_clr;

        if(load_layerpara_state)
            layer_para_r <= layer_para;

        if (weight_mem_clr_r == 1'b1)
            weight_sel_r <= 0;
        else if (weigth_mem_en_r) begin

            for (i=0; i<N_BUF; i=i+1) wraddr[i] <= wraddr[i] + mem_we[i];

            if(load_cnt == h_img)

                load_cnt_r <= 0;

                if(weight_sel_r == N_BUF - 1)
                    weight_sel_r <= 0;
                else
                    weight_sel_r <= weight_sel_r + 1;
            else
                load_cnt_r <= load_cnt;
        end





        if (load_kernel_state)
            if(kernel_sel_r == N_BUF - 1)
                kernel_sel_r <= 0;
            else
                kernel_sel_r <= kernel_sel_r + 1;
        else
            kernel_sel_r <= 0;



        if (rd_sel_r == N_BUF - 1)    
            rd_sel_r <= 0;
        else 
            rd_sel_r <= rd_sel_r + 1;
        
    end
end    

assign h_img = layer_para_r[15:0];



// FSM outputs.
always @(state) begin

    init_state	        = 0;
    load_layerpara_state = 0;
    load_kernel_state	= 0;
    compute_state	    = 0;

	case (state)

		INIT_ST:
			init_state       	= 1;

        LOAD_LAYERPARA_ST:
            load_layerpara_state = 1;


        LOAD_KERNEL_ST:
            load_kernel_state	= 1;

        COMPUTE_ST:
            compute_state       = 1;
	endcase
end





// strided write.
generate
genvar i;
	for (i=0; i < N_BUF; i=i+1) begin : GEN_WEIGHT_BUFFER

        // wrapper for BRAM primitives.
        weight_buffer #(
                .B_ADDR(B_BUF_ADDR),
                .B_DATA(B_BUF_DATA)
        	)
        	weight_buffer_i
        	(
        		.clk		    (clk		),
        		.rstn         	(rstn		),

                .rdaddr     (rdaddr[i]             ),
                .do         (mem_do[i]             ) ,

                .we         (mem_we[i] ),
                .wraddr     (wraddr[i]             ),
                .di         (mem_di_r             )
                               
        	);

        assign mem_we[i] = weigth_mem_en_r & ((weight_sel_r == i) ? 1'b1: 1'b0);

	end
endgenerate 

assign load_cnt = load_cnt_r + 1;




generate
genvar j;

	for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP

        assign dsp_group_di[j]  = { mem_do[rd_sel_r  ][j*16+:16], 
                                    mem_do[rd_sel_r+1][j*16+:16], 
                                    mem_do[rd_sel_r+2][j*16+:16]};

        assign partial_sum_i_arr[j] = (j==0) ? partial_sum_i: partial_sum_o_arr[j-1];
        assign inst_i_arr[j] = (j==0) ? inst_i: inst_o_arr[j-1];

        dsp_group 
            #(
    
            )
            dsp_group_i
            (
                .clk 		   (clk                 ),
                .rstn		   (rstn                ),

                .kernel_we     (kernel_we[i]        ),
                .kernel_di     (mem_di_r            ),

                .inst_i        (inst_i_arr[j]       ),
                .inst_o        (inst_o_arr[j]       ),

                .di            (dsp_group_di[j]     ),

                .partial_sum_i (partial_sum_i_arr[j]),
                .partial_sum_o (partial_sum_o_arr[j])
            );

        assign kernel_we[i] = load_kernel_state & ((kernel_sel_r == i) ? 1'b1: 1'b0);
	end
endgenerate 

assign partial_sum_o = partial_sum_o_arr[N_DSP_GROUP-1];
assign inst_o = inst_o_arr[N_DSP_GROUP-1];







// wire [16*(N_MAC + 2)-1:0] wei_i;
// reg [16*(N_MAC + 2)-1:0] wei;
// reg [16*(N_MAC + 2)-1:0] fm;
// wire [15:0] res[0:N_MAC-1];
// reg [8:0] addr_b_r;



// always @( posedge aclk )
// begin
//     if ( aresetn == 1'b0 ) begin
//         wei  <= 48'hfff1_0038_006E; // 110, 56, -15
//         fm <= 48'h0100_ffd2_ff9c; // -100, -46, 256
// 		addr_b_r <= 0;

//     end 
//     else begin    

//         if (mem_we) begin   
// 			addr_b_r <= addr_b_r + 1;	
//         end

//     end
// end    



// generate
// genvar i;
// 	for (i=0; i < N_MAC; i=i+1) begin : GEN_i

// 		mac_v2 
// 			#(
// 				.N_MUL(3)
// 			)
// 			mac_v2_i
// 			(
// 				.clk 		(aclk),
// 				.rstn		(aresetn),

// 				.wei        (wei_i[16*i+:16*3]),
// 				.fm         (fm[16*i+:16*3]),

// 				.WSTART_REG (WSTART_REG),
// 				.RSTART_REG (RSTART_REG),

// 				.res (res[i])
// 			);
// 	end
// endgenerate 

endmodule