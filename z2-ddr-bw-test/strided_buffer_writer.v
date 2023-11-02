module strided_buffer_reader
    #(
        parameter N_BUF_X = 10, 
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 25,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
        parameter N_CONV_UNIT = 8,
        
         
    )
    (
        input wire                           clk     ,    
        input wire                           rstn    , 

        input wire  [B_SHAPE-1:0]  shape,
        input wire  [6:0]          n_wrap_c_sum,

        input  wire [DATA_WIDTH-1:0] wr_di  ,
        output wire [DATA_WIDTH-1:0] wr_do  ,
        input  wire                  wr_en  ,
        output wire [N_BUF_X-1:0]    wr_sel ,
        output wire [B_BUF_ADDR:0]   wr_addr,
        output wire                  wr_last,
        output wire                  wr_tog,
        output wire [B_BUF_ADDR-1:0] wr_base,
        output wire [B_COORD-1:0]    wr_ptr         

    );



reg                  wr_en_r;
reg                  tog_r;
reg [DATA_WIDTH-1:0] di_r;



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

        wr_en_r        <= 0;
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

        di_r     <= wr_di;
        wr_en_r  <= wr_en;

        if (wr_en_r) begin
            
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

                        wr_base_r <= wr_addr[B_BUF_ADDR-1:0];

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




// strided write.
generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1)
        assign wr_sel[i] = wr_en_r & ((x_rem_r == i) ? 1'b1: 1'b0);
endgenerate 


assign wr_last = (c_next == n_wrap_c) && (y_next == h_i) && (x_next == w_i);

assign wr_addr = n_wrap_c_sum * (y_r + h_i * x_quo_r) + n_wrap_c_acc_r + c_r + wr_base_r;

assign x_next = x_r + 1;
assign y_next = y_r + 1;
assign c_next = c_r + 1;

assign w_i      = shape[0+:9] ;
assign h_i      = shape[9+:9] ;
assign n_wrap_c = shape[18+:7]; // n_wrap_c != n_wrap_c_sum.


assign wr_tog = tog_r;

assign wr_base = wr_base_r; 
assign wr_ptr = x_r;




assign wr_do = di_r;

endmodule