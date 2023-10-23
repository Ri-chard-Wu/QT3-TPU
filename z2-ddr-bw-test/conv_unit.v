



module conv_unit
    #(
        parameter N_BUF = 5, 
        parameter N_DSP_GROUP = 4, 
        parameter N_DSP = 3,
        parameter B_PIXEL = 16,
        parameter N_INST = 32,
    
        parameter B_BUF_ADDR = 9, 
        parameter B_BUF_DATA = 64, 
        parameter DATA_WIDTH = 64
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire                  mem_en,
        input wire [DATA_WIDTH-1:0] mem_di,

        input wire [B_PIXEL-1:0] partial_sum_i,
        input wire [B_PIXEL-1:0] partial_sum_o,

        input wire [N_INST-1:0] inst_i,
        input wire [N_INST-1:0] inst_o

        // input wire               WSTART_REG ,
        // input wire               RSTART_REG, 
        
        // output wire [15:0]       res
    );



wire [DATA_WIDTH-1 : 0] mem_di;
wire [DATA_WIDTH-1 : 0] mem_do       [0:N_BUF-1];
wire [N_BUF-1:0]        mem_we;

wire [B_BUF_ADDR-1:0]   rdaddr [0:N_BUF-1];
wire [B_BUF_ADDR-1:0]   wraddr [0:N_BUF-1];

reg  [7:0]              wr_sel_r;
reg  [7:0]              rd_sel_r;

wire [B_PIXEL-1:0] ps_i [0:N_DSP_GROUP-1];
wire [B_PIXEL-1:0] ps_o [0:N_DSP_GROUP-1];

wire [N_INST-1:0] inst_i_arr [0:N_DSP_GROUP-1];
wire [N_INST-1:0] inst_o_arr [0:N_DSP_GROUP-1];

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
        		.clk		    (aclk			),
        		.rstn         	(aresetn		),

                .rdaddr     (rdaddr[i]             ),
                .do         (mem_do[i]             ) 

                .we         (mem_we[i] ),
                .wraddr     (wraddr[i]             ),
                .di         (mem_di             )
                               
        	);

        assign mem_we[i] = mem_en & ((wr_sel_r == i) ? 1'b1: 1'b0);

	end
endgenerate 


wire [B_PIXEL*3-1:0] dsp_group_di [0:N_DSP_GROUP-1];


generate
genvar j;

	for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP

        assign dsp_group_di[j]  = { mem_do[rd_sel_r  ][j*16+:16], 
                                    mem_do[rd_sel_r+1][j*16+:16], 
                                    mem_do[rd_sel_r+2][j*16+:16]};

        assign ps_i[j] = (j==0) ? partial_sum_i: ps_o[j-1];
        assign inst_i_arr[j] = (j==0) ? inst_i: inst_o_arr[j-1];

        dsp_group 
            #(
    
            )
            dsp_group_i
            (
                .clk 		(aclk),
                .rstn		(aresetn),

                .inst_i (inst_i_arr[j]),
                .inst_o (inst_o_arr[j]),

                .di        (dsp_group_di[j]),

                .partial_sum_i (ps_i[j]),
                .partial_sum_o (ps_o[j])
            );
	end
endgenerate 

assign partial_sum_o = ps_o[N_DSP_GROUP-1];
assign inst_o = inst_o_arr[N_DSP_GROUP-1];



always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
        wr_sel_r <= 0;
        rd_sel_r <= 0;
    end 
    else begin    




        if (wr_sel_r == N_BUF - 1) begin   
            wr_sel_r <= 0;
        end
        else begin
            wr_sel_r <= wr_sel_r + 1;
        end


        if (rd_sel_r == N_BUF - 1) begin   
            rd_sel_r <= 0;
        end
        else begin
            rd_sel_r <= rd_sel_r + 1;
        end
    end
end    




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