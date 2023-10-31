module strided_buffer_reader
    #(
        parameter N_BUF_X = 10, 
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 32,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
        parameter N_CONV_UNIT = 8,
        
         
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input wire          [1:0]  stride,
        input wire          [1:0]  pad ,

        input wire  [B_SHAPE-1:0]  wei_shape,
        input wire  [B_SHAPE-1:0]  ftm_shape,

        input wire                  start,
        output wire [B_BUF_ADDR*N_BUF_X-1:0] rd_addr,
        
        output wire   [3:0] rd_sel,
        output wire   tog // toggle whenever one complete sweep of the ftm is done.
    );

reg tog_r;


reg   [3:0]            x_quo_base_r     ; // quotient of x / N_BUF_X.
reg   [3:0]            x_rem_base_r     ; // remainder of x / N_BUF_X.
wire  [3:0]           x_quo_base_next   ; 
wire  [3:0]           x_rem_base_next   ; 


reg   [3:0]            x_quo_r     ;
reg   [3:0]            x_rem_r     ;


reg  [B_COORD-1:0]    x_r;
reg  [B_COORD-1:0]    y_r;

reg  [7:0]            dx_r;
reg  [7:0]            dy_r;
reg  [7:0]            dc_r;

wire  [7:0]           dx_lim;
wire  [7:0]           dy_lim;
wire  [7:0]           dc_lim;

wire [B_COORD-1:0]    x_next;
wire [B_COORD-1:0]    y_next;

wire [B_BUF_ADDR-1:0] addr     ;


wire [7:0] n_wrap_c;

wire [15:0]        c_wei;
wire [B_COORD-1:0] h_wei;
wire [B_COORD-1:0] w_wei;

wire [15:0]        c_ftm;
wire [B_COORD-1:0] h_ftm;
wire [B_COORD-1:0] w_ftm;

integer i;


wire  [B_COORD-1:0]    x_min;
wire  [B_COORD-1:0]    y_min;
wire  [B_COORD-1:0]    x_max;
wire  [B_COORD-1:0]    y_max;



always @( posedge clk )
begin
    if (rstn == 1'b0) begin
                
       
        x_quo_base_r <= 0;
        x_rem_base_r <= 0;        

        x_quo_r <= 0;
        x_rem_r <= 0;

        dx_r <= 0;
        dy_r <= 0;
        dc_r <= 0;

        x_r <= 0;
        y_r <= 0;

        tog_r <= 0;

    end 
    else begin    

		case(state)

			INIT_ST:
                if (start == 1'b1)
                    state <= COMPUTE_ST;
	
            COMPUTE_ST:
                if()

		endcase	


        if(compute_state == 1'b1) begin
            
            if(dc_r == dc_lim) begin

                // sweep [y, y + dy]
                if(dy_r == dy_lim) begin  // if reached y + dy end.

                    dy_r <= 0;

                    // sweep [x, x + dx]
                    if(dx_r == dx_lim) begin  // if reached x + dx end.

                        dx_r <= 0;

                        if(y_next > h_ftm + 2*pad - h_wei) begin // reached bottom boundary of fm.
                            
                            y_r <= 0;

                            if(x_next > w_ftm + 2*pad - w_wei) begin // reached right boundary of fm.
                                
                                tog_r <= ~tog_r;

                                x_r <= 0;                            

                                x_quo_base_r <= 0;
                                x_rem_base_r <= 0;
                                x_quo_r      <= 0;
                                x_rem_r      <= 0;  
                            end
                            else begin

                                x_r <= x_next;

                                x_quo_base_r <= x_quo_base_next;
                                x_rem_base_r <= x_rem_base_next;
                                x_quo_r      <= x_quo_base_next;
                                x_rem_r      <= x_rem_base_next;  
                            end
            
                        end
                        else begin
                            y_r <= y_next;   

                            x_quo_r <= x_quo_base_r;
                            x_rem_r <= x_rem_base_r;
                        end
                    end 
                    else begin

                        dx_r <= dx_r + 1;

                        if (x_rem_r == N_BUF_X - 1) begin
                            x_rem_r <= 0;
                            x_quo_r <= x_quo_r + 1;
                        end
                        else begin
                            x_rem_r <= x_rem_r + 1;
                        end  
                    end

                end
                else 
                    dy_r <= dy_r + 1;
            end
            else    
                dc_r <= dc_r + 1;

        end
        else begin
            x_r <= 0;
            y_r <= 0;
        end

      
    end
end    




assign x_min = pad;
assign y_min = pad;
assign x_max = (w_ftm-1) + pad;
assign y_max = (h_ftm-1) + pad;


// assign x_quo_base_next = (x_rem_base_r == N_BUF_X-1)? x_quo_base_r + 1 : x_quo_base_r    ;
// assign x_rem_base_next = (x_rem_base_r == N_BUF_X-1)? 0                : x_rem_base_r + 1;

// assume stride < N_BUF_X so will warp at most once (x_quo_base_r increment at most by 1).
assign x_quo_base_next = (x_rem_base_r + stride > N_BUF_X-1)? x_quo_base_r + 1 : 
                                                              x_quo_base_r;
assign x_rem_base_next = (x_rem_base_r + stride > N_BUF_X-1)? N_BUF_X - (x_rem_base_r + stride) : 
                                                              x_rem_base_r + stride;

assign x_next = x_r + stride;
assign y_next = y_r + stride;

assign c_wei = wei_shape[31:20]; // 12-bits
assign h_wei = wei_shape[19:10]; // 10-bits
assign w_wei = wei_shape[9:0]  ; // 10-bits

assign c_ftm = ftm_shape[31:20]; // 12-bits
assign h_ftm = ftm_shape[19:10]; // 10-bits
assign w_ftm = ftm_shape[9:0]  ; // 10-bits

assign n_wrap_c = (c_wei >> $clog2(4*N_CONV_UNIT));

assign dx_lim = w_wei - 1;
assign dy_lim = h_wei - 1;
assign dc_lim = n_wrap_c - 1;

// assign dcy_lim = h_wei * n_wrap_c - 1;

// y * n_wrap_c + h_wei * n_wrap_c * floor(x / N_BUF_X)
assign addr = n_wrap_c * (y_r + dy + h_ftm * x_quo_r) + dc_r;

// if [x, y] is in padded region, set sel to be an invalid value (N_BUF_X) so that the 
    // mux will assign fd_do to be 0.
assign rd_sel = ((y_r + dy_r < y_min || y_r + dy_r > y_max) ||
                 (x_r + dx_r < x_min || x_r + dx_r > x_max)) ? N_BUF_X : x_rem_r;

generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

        assign rd_addr[i*B_BUF_ADDR+:B_BUF_ADDR] = (i == x_rem_r) ? addr: 0;
    end
endgenerate 


assign tog = tog_r;

endmodule