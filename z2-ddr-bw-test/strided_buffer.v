module strided_buffer
    #(
        parameter N_BUF_X = 5, 
        parameter N_DSP = 3,
        parameter B_BUF_ADDR = 9,
        parameter B_DSHAPE = 48,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
         
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 
        
           

        input wire  [B_DSHAPE-1:0]  dshape,

        input wire                          clr,
        input wire                          we ,
        input wire [DATA_WIDTH-1:0]         di ,
        
        input wire                           start,  
        output wire [DATA_WIDTH*N_BUF_X-1:0] do   ,

        output wire [3*B_COORD-1:0] cur_coord,
        output wire done_ld 
    );



reg  we_r;
reg  clr_r;


reg  [DATA_WIDTH-1:0] di_r;


wire [N_BUF_X-1:0]        we_i;

reg  [B_BUF_ADDR-1:0] wraddr [0:N_BUF_X-1];

reg  [2:0] sel_wr;

reg  [B_COORD-1:0] c_wr_r;
reg  [B_COORD-1:0] y_wr_r;
reg  [B_COORD-1:0] x_wr_r; // max is 80.
wire [B_COORD-1:0] c_wr_next;
wire [B_COORD-1:0] y_wr_next;
wire [B_COORD-1:0] x_wr_next;



reg  [3:0]            qx_rd_r   [0:N_DSP-1]; // quotient of x / N_BUF_X.
reg  [3:0]            rx_rd_r   [0:N_DSP-1]; // remainder of x / N_BUF_X.
reg  [B_COORD-1:0]    p_rd_r    [0:1];
wire [B_COORD-1:0]    p_rd_next [0:1];
wire [B_BUF_ADDR-1:0] rdaddr    [0:N_BUF_X-1];


wire [7:0] n_wrap_c;

wire [15:0] c_i;
wire [B_COORD-1:0] h_i;
wire [B_COORD-1:0] w_i;

wire [B_COORD-1:0] c_rd;
wire [B_COORD-1:0] y_rd;
wire [B_COORD-1:0] x_rd;


integer i;

always @( posedge clk )
begin
    if (rstn == 1'b0) begin

        we_r        <= 0;
        clr_r       <= 0;
        di_r        <= 0;

        y_wr_r      <= 0;
        x_wr_r      <= 0;
        c_wr_r      <= 0;

        sel_wr      <= 0;
                
        for (i=0; i<N_DSP; i=i+1) begin
            qx_rd_r[i] <= 0;
            rx_rd_r[i] <= 0;        
        end

        for (i=0; i<2; i=i+1) p_rd_r[i] <= 0;
        for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= 0;

    end 
    else begin    

        di_r  <= di;
        we_r  <= we;
        clr_r <= clr;


		case(state)

			INIT_ST:
                if (start == 1'b1)
                    state <= COMPUTE_ST;
	
            COMPUTE_ST:
                if()

		endcase	


        if(compute_state == 1'b1) begin
        
            
            if(p_rd_next[1] == h_i) begin
                
                p_rd_r[1] <= 0;

                p_rd_r[0] <= p_rd_next[0];

                for (i=0; i<N_DSP; i=i+1) begin

                    if(rx_rd_r[i] == N_BUF_X-1) begin
                        rx_rd_r[i] <= 0;
                        qx_rd_r[i] <= qx_rd_r[i] + 1;
                    end
                    else 
                        rx_rd_r[i] <= rx_rd_r[i] + 1;
                end

            end
            else 
                p_rd_r[1] <= p_rd_next[1];

        end
        else begin
            for (i=0; i<2; i=i+1) p_rd_r[i] <= 0;
        end




        if (clr_r == 1'b1) begin
        
            we_r        <= 0;
            clr_r       <= 0;
            di_r        <= 0;

            y_wr_r <= 0;
            x_wr_r <= 0;
            c_wr_r <= 0;

            sel_wr      <= 0;

        end
        else if (we_r) begin
            // c
            if(c_wr_next == n_wrap_c) begin
                c_wr_r <= 0;
                // y
                if(y_wr_next == h_i) begin
                    y_wr_r <= 0;
                    // x
                    x_wr_r <= x_wr_next;
                    if(sel_wr == N_BUF_X - 1)
                        sel_wr <= 0;
                    else
                        sel_wr <= sel_wr + 1;  
                end              
                else
                    y_wr_r <= y_wr_next;
            end
            else
                c_wr_r <= c_wr_next;
            for (i=0; i<N_BUF_X; i=i+1) wraddr[i] <= wraddr[i] + we_i[i];
        end



   
  
      
    end
end    




assign p_rd_next[0] = p_rd_r[0] + 1;
assign p_rd_next[1] = p_rd_r[1] + 1;




assign c_wr_next = c_wr_r + 1;
assign y_wr_next = y_wr_r + 1;
assign x_wr_next = x_wr_r + 1;


assign c_i = dshape[0*16+:16];
assign h_i = dshape[1*16+:16];
assign w_i = dshape[2*16+:16];

assign n_wrap_c = (c_i >> 6);


// y * n_wrap_c + h_i * n_wrap_c * floor(x / N_BUF_X)
assign rdaddr[rx_rd_r[0]] = n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[0]);
assign rdaddr[rx_rd_r[1]] = n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[1]);
assign rdaddr[rx_rd_r[2]] = n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[2]);




// strided write.
generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

        // wrapper for BRAM primitives.
        bram_sdp bram_sdp_i
        	(
        		.clk		(clk		                    ),
        		.rstn       (rstn		                    ),

                .we         (we_i[i]                          ),
                .wraddr     (wraddr[i]                      ),
                .di         (di_r                           )

                .rdaddr     (rdaddr[i]                       ),
                .do         (do[i*DATA_WIDTH+:DATA_WIDTH]   ),       
        	);

        assign we_i[i] = we_r & ((sel_wr == i) ? 1'b1: 1'b0);

        assign rdaddr[i] = (i == rx_rd_r[0]) ? n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[0]):
	                       (i == rx_rd_r[1]) ? n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[1]):
                           (i == rx_rd_r[2]) ? n_wrap_c * (p_rd_r[1] + h_i * qx_rd_r[2]): 0;
        
        end
endgenerate 


assign cur_coord = {c_wr_r, y_wr_r, x_wr_r};

assign done_ld = (x_wr_r == w_i);

endmodule