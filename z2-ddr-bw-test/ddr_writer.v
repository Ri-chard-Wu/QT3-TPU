module ddr_writer
    #(
        parameter N_KERNEL = 4, 
        parameter B_PIXEL = 16,
        parameter DATA_WIDTH = 64,
        parameter ADDR_WIDTH = 32	,
        parameter N_DSP_GROUP = 4		
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input wire                      ddr_we ,
        input wire [N_KERNEL*B_PIXEL:0] ddr_di  ,
        
        input wire [31:0]               base_addr,
        input wire [31:0]               shape,

        output wire	[DATA_WIDTH+ADDR_WIDTH-1:0]	m_axis_tdata ,
        output wire	                	        m_axis_tvalid,
        input  wire						        m_axis_tready
    );


wire [9:0]  w;
wire [9:0]  h;
wire [11:0] c;

reg [11:0]               dc_r;
reg [ADDR_WIDTH-1:0]     dxy_r;

reg  [ADDR_WIDTH-1:0]     addr_r;
wire [ADDR_WIDTH-1:0]     addr_i;

reg  [19:0]     cnt_xy_r;
wire [19:0]     cnt_xy_lim;

reg                      ddr_we_r;
reg [N_KERNEL*B_PIXEL:0] ddr_di_r;

always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin

        dc_r     <= 0;
        dxy_r    <= 0;
        cnt_xy_r <= 0;
        addr_r   <= 0;

        ddr_we_r <= 0;
        ddr_di_r <= 0;        
    end 
    else begin    

        // compute next addr offset.
        if(ddr_we)begin 
            
            if(cnt_xy_r == cnt_xy_lim)begin
                
                dc_r     <= dc_r + N_DSP_GROUP * (B_PIXEL/8); 
                dxy_r   <= 0;
            end
            else begin

                dxy_r   <= dxy_r + c * (B_PIXEL/8); 
                cnt_xy_r <= cnt_xy_r + 1;
            end
        end
        
        ddr_we_r <= ddr_we; 
        ddr_di_r <= ddr_di; 
        addr_r   <= addr_i; 
    end
end    

assign addr_i = base_addr + dxy_r + dc_r;

assign w = shape[9:0]  ; 
assign h = shape[19:10]; 
assign c = shape[31:20]; 

assign cnt_xy_lim = w * h;

assign m_axis_tdata[DATA_WIDTH-1:0]                     = ddr_di_r;
assign m_axis_tdata[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH] = addr_r;
assign m_axis_tvalid                                    = ddr_we_r;


endmodule