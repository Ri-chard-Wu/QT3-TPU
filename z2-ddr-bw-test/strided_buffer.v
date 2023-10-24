module strided_buffer
    #(
        parameter N_BUF_X = 5, 
        parameter N_DSP = 3,
        parameter B_DSHAPE = 48,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
         
    )
    (
        input wire                  clk    ,    
        input wire                  rstn   ,     

        input wire  [B_DSHAPE-1:0]  dshape,

        input wire                          clr,
        
        input wire                          en,
        input wire [DATA_WIDTH-1:0]         di,
        


        // x, y coord of a pixel, each 8-bits.
        input wire [] rd_coord, 

        output wire [DATA_WIDTH*N_BUF_X-1:0] do,


        output wire [3*B_COORD-1:0] cur_coord
    );



reg  en_r;
reg  clr_r;


reg  [DATA_WIDTH-1:0] di_r;


wire [N_BUF_X-1:0]        we;

reg  [B_BUF_ADDR-1:0] wraddr [0:N_BUF_X-1];

reg  [2:0] wr_sel;
// reg  [2:0] rd_sel [0:N_DSP-1];

reg  [B_COORD-1:0]  cnt_c_r;
reg  [B_COORD-1:0]  cnt_y_r;
reg  [B_COORD-1:0]  cnt_x_r; // max is 80.
wire [B_COORD-1:0] cnt_c_next;
wire [B_COORD-1:0] cnt_y_next;
wire [B_COORD-1:0] cnt_x_next;

wire [7:0] n_wrap_c;

wire [15:0] c_i;
wire [15:0] h_i;
wire [15:0] w_i;



integer i;

always @( posedge clk )
begin
    if (rstn == 1'b0) begin
    
        for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= 0;
        
        en_r        <= 0;
        clr_r       <= 0;
        di_r        <= 0;

        cnt_y_r <= 0;
        cnt_x_r <= 0;
        cnt_c_r <= 0;

        wr_sel      <= 0;
        
        // for (i=0; i<N_DSP; i=i+1) rd_sel[i] <= i[2:0];
        

    end 
    else begin    

        di_r  <= di;
        en_r  <= en;
        clr_r <= clr;


        if (clr_r == 1'b1) begin
        
            en_r        <= 0;
            clr_r       <= 0;
            di_r        <= 0;

            cnt_y_r <= 0;
            cnt_x_r <= 0;
            cnt_c_r <= 0;

            wr_sel      <= 0;

        end
        else if (en_r) begin

            
            for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= wraddr[i] + we[i];

            if(cnt_c_next == n_wrap_c) begin

                cnt_c_r <= 0;
                
                if(cnt_y_next == h_i) begin

                    cnt_y_r <= 0;
                    
                    if(cnt_x_next == w_i) 
                        cnt_x_r <= cnt_x_r;
                    else
                        cnt_x_r <= cnt_x_next;

                    if(wr_sel == N_BUF_X - 1)
                        wr_sel <= 0;
                    else
                        wr_sel <= wr_sel + 1;  
                end              
                else
                    cnt_y_r <= cnt_y_next;
            end
            else
                cnt_c_r <= cnt_c_next;
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

assign n_wrap_c = (c_i >> 6);


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


assign cnt_c_next = cnt_c_r + 1;
assign cnt_y_next = cnt_y_r + 1;
assign cnt_x_next = cnt_x_r + 1;

endmodule