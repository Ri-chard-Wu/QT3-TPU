module strided_buffer
    #(
        parameter N_BUF_X = 5, 
        // parameter N_DSP = 3,
        
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 25,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,

		parameter UNIT_BURSTS = 32,  // need to be power of 2.
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 
    
        input wire  [B_SHAPE-1:0]  shape,
        input wire  [6:0]          n_wrap_c_sum,

        input wire                          clr,
        input wire                          we ,
        input wire [DATA_WIDTH-1:0]         di ,
        
        input wire [B_BUF_ADDR*N_BUF_X-1:0] rdaddr;
        output wire [DATA_WIDTH*N_BUF_X-1:0] do   ,

        output wire tog,
        // output wire full,

        output wire [B_BUF_ADDR-1:0]  wptr
    );

localparam N_BUF_ENTRIES = 512;


reg                  we_r;
reg                  clr_r;
reg                  tog_r;
reg [DATA_WIDTH-1:0] di_r;

wire [N_BUF_X-1:0]    we_i;
wire [B_BUF_ADDR:0] wraddr ;

reg  [B_COORD-1:0] c_r;
reg  [B_COORD-1:0] y_r;
reg  [B_COORD-1:0] x_r; // max is 80.
wire [B_COORD-1:0] c_next;
wire [B_COORD-1:0] y_next;
wire [B_COORD-1:0] x_next;
reg  [3:0]         x_quo_r  ;
reg  [3:0]         x_rem_r  ;

wire [B_COORD-1:0] h_i;
wire [B_COORD-1:0] w_i;
wire [6:0]         n_wrap_c;
reg  [6:0]         n_wrap_c_acc_r;


always @( posedge clk )
begin
    if (rstn == 1'b0) begin

        we_r        <= 0;
        clr_r       <= 0;
        di_r        <= 0;

        y_r      <= 0;
        x_r      <= 0;
        c_r      <= 0;

        tog_r <= 0;
                
        x_quo_r <= 0;
        x_rem_r <= 0;

        n_wrap_c_acc_r <= 0;

    end 
    else begin    

        di_r  <= di;
        we_r  <= we;
        clr_r <= clr;


        // TODO: combine clr into rstn.
        if (clr_r == 1'b1) begin
        
            we_r        <= 0;
            clr_r       <= 0;
            di_r        <= 0;

            y_r      <= 0;
            x_r      <= 0;
            c_r      <= 0;

            tog_r <= 0;

            x_quo_r <= 0;
            x_rem_r <= 0;      

            n_wrap_c_acc_r <= 0;     
                    
        end
        else if (we_r) begin
            
            // TODO: be able to handle cases where c1 is not power of 2 (e.g. input img).

  
            // c
            if(c_next == n_wrap_c) begin
                c_r <= 0;
                // y
                if(y_next == h_i) begin
                    y_r <= 0;
                    // x
                    if(x_next == w_i) begin
                        x_r <= 0;

                        tog_r <= ~tog_r;

                        wptr_r <= wraddr[B_BUF_ADDR-1:0];

                        n_wrap_c_acc_r <= n_wrap_c_acc_r + n_wrap_c;

                        x_quo_r <= 0;
                        x_rem_r <= 0;
                    end              
                    else begin
                        x_r <= x_next;

                        if(x_rem_r == N_BUF_X - 1) begin
                            x_rem_r <= 0;
                            x_quo_r <= x_quo_r + 1;
                        end
                        else begin
                            x_rem_r <= x_rem_r + 1;
                            x_quo_r <= x_quo_r;
                        end
                    end
                end              
                else
                    y_r <= y_next;
            end
            else
                c_r <= c_next;
        end

    end
end    

assign wraddr = n_wrap_c_sum * (y_r + h_i * x_quo_r) + n_wrap_c_acc_r + c_r + wptr_r;
assign wptr = wraddr[B_BUF_ADDR-1:0];

assign x_next = x_r + 1;
assign y_next = y_r + 1;
assign c_next = c_r + 1;

assign w_i      = shape[0+:9] ;
assign h_i      = shape[9+:9] ;
assign n_wrap_c = shape[18+:7]; // n_wrap_c != n_wrap_c_sum.



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
                .wraddr     (wraddr[B_BUF_ADDR-1:0]         ),
                .di         (di_r                           )

                .rdaddr     (rdaddr[i*B_BUF_ADDR+:B_BUF_ADDR] ),
                .do         (do[i*DATA_WIDTH+:DATA_WIDTH]   ),       
        	);

        assign we_i[i] = we_r & ((x_rem_r == i) ? 1'b1: 1'b0);

    end
endgenerate 

assign tog = tog_r;


endmodule