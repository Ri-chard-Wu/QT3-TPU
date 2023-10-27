module weight_buffer_reader
    #(
        parameter N_BUF_X = 5, 
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 48,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
         
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 
        
        input wire  [B_SHAPE-1:0]  wei_shape,
        input wire  [B_SHAPE-1:0]  ker_shape,

        input wire                  start,
        output wire [B_BUF_ADDR*N_BUF_X-1:0] rdaddr,

        input wire [DATA_WIDTH * N_WEIBUF_X-1:0] di,
        output wire [DATA_WIDTH-1:0]     do
    
    );



reg   [3:0]            qx_base_r     ; // quotient of x / N_BUF_X.
reg   [3:0]            rx_base_r     ; // remainder of x / N_BUF_X.
wire  [3:0]           qx_base_next   ; // quotient of x / N_BUF_X.
wire  [3:0]           rx_base_next   ; // remainder of x / N_BUF_X.


reg   [3:0]            qx_r     ; // quotient of x / N_BUF_X.
reg   [3:0]            rx_r     ; // remainder of x / N_BUF_X.
wire  [3:0]           qx_next   ; // quotient of x / N_BUF_X.
wire  [3:0]           rx_next   ; // remainder of x / N_BUF_X.


reg  [B_COORD-1:0]    p_r    [0:1];
reg  [7:0]            dp_r [0:1];
wire  [7:0]           dp_lim[0:1];

wire [B_COORD-1:0]    p_next [0:1];
wire [B_BUF_ADDR-1:0] addr     ;


wire [7:0] n_wrap_c;

wire [15:0]        c_wei;
wire [B_COORD-1:0] h_wei;
wire [B_COORD-1:0] w_wei;

wire [15:0]        c_ker;
wire [B_COORD-1:0] h_ker;
wire [B_COORD-1:0] w_ker;

integer i;

always @( posedge clk )
begin
    if (rstn == 1'b0) begin
                
       
        qx_base_r <= 0;
        rx_base_r <= 0;        

        dp_r[0] <= 0;
        dp_r[1] <= 0;

        for (i=0; i<2; i=i+1) p_r[i] <= 0;

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
        
            if(dp_r[1] == dp_lim[1]) begin // dy
                
                dp_r[1] <= 0;

                qx_r <= qx_next;
                rx_r <= rx_next;

                if(dp_r[0] == dp_lim[0]) begin // dx

                    dp_r[0] <= 0;

                    if(p_next[1] == h_wei) begin // y & x
                        
                        p_r[1] <= 0;
                        p_r[0] <= p_next[0];

                        qx_base_r <= qx_base_next;
                        rx_base_r <= rx_base_next;

                    end
                    else 
                        p_r[1] <= p_next[1];                
                end 
                else begin
                    dp_r[0] <= dp_r[0] + 1;
                end
            end
            else begin
                dp_r[1] <= dp_r[1] + 1;
            end

        end
        else begin
            for (i=0; i<2; i=i+1) p_r[i] <= 0;
        end

      
    end
end    



assign qx_base_next = (rx_base_r == N_BUF_X-1)? qx_base_r + 1 : qx_base_r    ;
assign rx_base_next = (rx_base_r == N_BUF_X-1)? 0             : rx_base_r + 1;


assign qx_next = (dp_r[0] == dp_lim[0]) ? qx_base_r :
                 (rx_r == N_BUF_X-1)    ? qx_r + 1  : qx_r    ;
assign rx_next = (dp_r[0] == dp_lim[0]) ? rx_base_r : 
                 (rx_r == N_BUF_X-1)    ? 0         : rx_r + 1;


assign p_next[0] = p_r[0] + 1;
assign p_next[1] = p_r[1] + 1;

assign c_wei = wei_shape[0*16+:16];
assign h_wei = wei_shape[1*16+:16];
assign w_wei = wei_shape[2*16+:16];

assign c_ker = ker_shape[0*16+:16];
assign h_ker = ker_shape[1*16+:16];
assign w_ker = ker_shape[2*16+:16];

assign n_wrap_c = (c_wei >> 6);

assign dp_lim[0] = w_ker - 1;
assign dp_lim[1] = h_ker * n_wrap_c - 1;

// y * n_wrap_c + h_wei * n_wrap_c * floor(x / N_BUF_X)
assign addr = n_wrap_c * (p_r[1] + h_wei * qx_r) + dp_r[1];




generate
genvar i;
	for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

        assign rdaddr[i*B_BUF_ADDR+:B_BUF_ADDR] = (i == rx_base_r) ? addr: 0;
        

    end
endgenerate 


assign do = (0 == rx_r) ? di[0*DATA_WIDTH+:DATA_WIDTH] :
            (1 == rx_r) ? di[1*DATA_WIDTH+:DATA_WIDTH] :
            (2 == rx_r) ? di[2*DATA_WIDTH+:DATA_WIDTH] :
            (3 == rx_r) ? di[3*DATA_WIDTH+:DATA_WIDTH] :
            (4 == rx_r) ? di[4*DATA_WIDTH+:DATA_WIDTH] : 0;



endmodule