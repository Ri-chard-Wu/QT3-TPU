module ftm_buffer_reader
    #(
        parameter N_BUF_X = 5, 
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 32,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
         
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 
        
        input wire  [B_SHAPE-1:0]  wei_shape,
        input wire  [B_SHAPE-1:0]  ftm_shape,

        input wire                  start,
        output wire [B_BUF_ADDR*N_BUF_X-1:0] rdaddr,
        
        output wire   [3:0] rd_sel
    );



reg   [3:0]            qx_base_r     ; // quotient of x / N_BUF_X.
reg   [3:0]            rx_base_r     ; // remainder of x / N_BUF_X.
wire  [3:0]           qx_base_next   ; 
wire  [3:0]           rx_base_next   ; 


reg   [3:0]            qx_r     ;
reg   [3:0]            rx_r     ;


reg  [B_COORD-1:0]    x_r;
reg  [B_COORD-1:0]    y_r;

reg  [7:0]            dx_r;
reg  [7:0]            dy_r;

wire  [7:0]           dx_lim;
wire  [7:0]           dy_lim;

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

always @( posedge clk )
begin
    if (rstn == 1'b0) begin
                
       
        qx_base_r <= 0;
        rx_base_r <= 0;        

        qx_r <= 0;
        rx_r <= 0;

        dx_r <= 0;
        dy_r <= 0;

        x_r <= 0;
        y_r <= 0;

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
        
            // sweep [y, y + dy]
            if(dy_r == dy_lim) begin  // if reach y + dy end.

                dy_r <= 0;

                // sweep [x, x + dx]
                if(dx_r == dx_lim) begin  // if reach x + dx end.

                    dx_r <= 0;

                    if(y_next == h_wei) begin // reached the bottom of fm.
                        
                        y_r <= 0;
                        x_r <= x_next;

                        qx_base_r <= qx_base_next;
                        rx_base_r <= rx_base_next;

                        qx_r      <= qx_base_next;
                        rx_r      <= rx_base_next;            
                    end
                    else begin
                        y_r <= y_next;   

                        qx_r <= qx_base_r;
                        rx_r <= rx_base_r;
                    end
                end 
                else begin

                    dx_r <= dx_r + 1;

                    if (rx_r == N_BUF_X - 1) begin
                        rx_r <= 0;
                        qx_r <= qx_r + 1;
                    end
                    else begin
                        rx_r <= rx_r + 1;
                    end  
                end

            end
            else begin
                dy_r <= dy_r + 1;
            end

        end
        else begin
            x_r <= 0;
            y_r <= 0;
        end

      
    end
end    


assign qx_base_next = (rx_base_r == N_BUF_X-1)? qx_base_r + 1 : qx_base_r    ;
assign rx_base_next = (rx_base_r == N_BUF_X-1)? 0             : rx_base_r + 1;


assign x_next = x_r + 1;
assign y_next = y_r + 1;

assign c_wei = wei_shape[31:20]; // 12-bits
assign h_wei = wei_shape[19:10]; // 10-bits
assign w_wei = wei_shape[9:0]  ; // 10-bits

assign c_ftm = ftm_shape[31:20];
assign h_ftm = ftm_shape[19:10];
assign w_ftm = ftm_shape[9:0]  ;

assign n_wrap_c = (c_wei >> 6);

assign dx_lim = w_ftm - 1;
assign dy_lim = h_ftm * n_wrap_c - 1;

// y * n_wrap_c + h_wei * n_wrap_c * floor(x / N_BUF_X)
assign addr = n_wrap_c * (y_r + h_wei * qx_r) + dy_r;




generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

        assign rdaddr[i*B_BUF_ADDR+:B_BUF_ADDR] = (i == rx_r) ? addr: 0;
    end
endgenerate 

assign rd_sel = rx_r;

endmodule