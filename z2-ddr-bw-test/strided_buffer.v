module strided_buffer
    #(
        parameter N_BUF_X = 5, 
        parameter N_DSP = 3,
        parameter B_DSHAPE = 48,
        parameter DATA_WIDTH = 64
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire  [B_DSHAPE-1:0]  dshape,

        input wire                          clr,
        
        input wire                          en,
        input wire [DATA_WIDTH-1:0]         di,
        

        input wire [] rdaddr,
        input wire [DATA_WIDTH*N_BUF_X-1:0] do
    );



reg  en_r;
reg  clr_r;


reg  [DATA_WIDTH-1:0] di_r;


wire [N_BUF_X-1:0]        we;

reg  [B_BUF_ADDR-1:0] wraddr [0:N_BUF_X-1];

reg  [2:0] wr_sel;
// reg  [2:0] rd_sel [0:N_DSP-1];

reg  [15:0] cnt_r;
wire [15:0] cnt;



wire [15:0] n_eps;
wire [15:0] c_i;
wire [15:0] h_i;
wire [15:0] w_i;



integer i;

always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
    
        for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= 0;
        
        en_r  <= 0;
        clr_r <= 0;
        di_r  <= 0;

        cnt_r   <= 0;
        wr_sel  <= 0;
        
        // for (i=0; i<N_DSP; i=i+1) rd_sel[i] <= i[2:0];
        


    end 
    else begin    

        di_r  <= di;
        en_r  <= en;
        clr_r <= clr;


        if (clr_r == 1'b1) begin
            wr_sel <= 0;
        end
        else if (en_r) begin

            for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= wraddr[i] + we[i];

            if(cnt == n_eps)

                cnt_r <= 0;

             
                if(wr_sel == N_BUF_X - 1)
                    wr_sel <= 0;
                else
                    wr_sel <= wr_sel + 1;
            
            else
                cnt_r <= cnt;
        end



        // for (i=0; i<N_DSP; i=i+1) begin

        //     if (rd_sel[i] == N_BUF_X - 1)    
        //         rd_sel[i] <= 0;
        //     else 
        //         rd_sel[i] <= rd_sel[i] + 1;
        // end

  
      
    end
end    

assign c_i = dshape[0*16+:16];
assign h_i = dshape[1*16+:16];
assign w_i = dshape[2*16+:16];

// eps: entries per slice.
assign n_eps = (c_i >> 6) * h_i;


// strided write.
generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

        // wrapper for BRAM primitives.
        bram_sdp bram_sdp_i
        	(
        		.clk		(clk		                    ),
        		.rstn       (rstn		                    ),

                .rdaddr     (rdaddr[]                       ),
                .do         (do[i*DATA_WIDTH+:DATA_WIDTH]   ),

                .we         (we[i]                          ),
                .wraddr     (wraddr[i]                      ),
                .di         (di_r                           )
                               
        	);

        assign we[i] = en_r & ((wr_sel == i) ? 1'b1: 1'b0);

	end
endgenerate 

assign cnt = cnt_r + 1;


endmodule