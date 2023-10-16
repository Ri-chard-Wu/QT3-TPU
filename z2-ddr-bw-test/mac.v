module mac
    #(
        parameter DATA_WIDTH	= 64
    )
    (
        input wire         clk		     ,    
        input wire         rstn           ,     

        input  wire                   m_axis_tvalid  ,     
        input  wire [DATA_WIDTH-1:0]  m_axis_tdata	 ,    
        input  wire                   m_axis_tready  , 

		output wire					  s_axis_tready	,
		input  wire	[DATA_WIDTH-1:0]  s_axis_tdata	,
		input  wire		 	          s_axis_tvalid	,

        input wire         start , 
        output wire [31:0] partial_sum,

        input wire         WSTART_REG ,
        input wire         RSTART_REG 
        
    );


wire [DATA_WIDTH-1 : 0] 	mem_di;
wire                        mem_we;

reg mem_we_r;
reg [DATA_WIDTH-1:0]	partial_sum_r;
reg [31:0] pv_1;

reg [DATA_WIDTH-1:0]	s_r;
wire [DATA_WIDTH-1:0]	s_i;


data_writer
    #(
        .DATA_WIDTH(DATA_WIDTH)
    )
    data_writer_i
	( 
        .clk    		(clk			),
		.rstn			(rstn			),

		// AXIS Slave.
		.s_axis_tdata	(m_axis_tdata  ),
		.s_axis_tvalid	(m_axis_tvalid ),
		.s_axis_tready	(m_axis_tready ),

		// Output data.
        .mem_we         (mem_we         ),
        .mem_di         (mem_di         )
    );




always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
        partial_sum_r  <= 0;
        pv_1 <= 0;
        mem_we_r <= 0;
    end 
    else begin    
        
        if(RSTART_REG) begin
            partial_sum_r <= 0;
        end
        else if (mem_we_r) begin   
            partial_sum_r <= partial_sum_r + s_r;
        end 

        mem_we_r <= mem_we;  
        s_r <= s_i;
    end
end    


assign s_i = mem_di[0*32+:32] + mem_di[1*32+:32];


assign s_axis_tvalid = WSTART_REG;
assign s_axis_tdata = partial_sum_r;





// generate
// genvar i0;
// 	for (i0=0; i0 < 8; i0=i0+1) begin : GEN_i0
//         assign byte_arr_signed[i0] = mem_di[i0*8 +: 8]; // == mem_di[(i0+1)*8-1:i0*8]
// 	end
// endgenerate 


// generate
// genvar i1;
// 	for (i1=0; i1 < 4; i1=i1+1) begin : GEN_i1
//         assign partial_sum_1[i1] = byte_arr_signed[2 * i1] + byte_arr_signed[2 * i1 + 1]; 
// 	end
// endgenerate 


// generate
// genvar i2;
// 	for (i2=0; i2 < 2; i2=i2+1) begin : GEN_i2
//         assign partial_sum_2[i2] = partial_sum_1[2 * i2] + partial_sum_1[2 * i2 + 1]; 
// 	end
// endgenerate 

// assign partial_sum_3 = partial_sum_2[0] + partial_sum_2[1];


// assign partial_sum = partial_sum_r;


// assign probe[1 * 32 +: 32] = pv_1;

endmodule
