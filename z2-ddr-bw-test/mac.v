module mac
    #(
        parameter B	= 64
    )
    (
        input wire         clk		     ,    
        input wire         rstn           ,     

        input wire            m_axis_tvalid  ,     
        input wire [B - 1:0]  m_axis_tdata	 ,    
        input wire            m_axis_tready  , 

        input wire         start , 
        output wire [31:0] partial_sum,

        input wire         RIDLE_REG   
    );


wire [B-1 : 0] 	mem_di;
wire            mem_we;

wire signed	[7:0]	byte_arr_signed	[0:7];
wire signed	[7:0]	partial_sum_1	[0:3];
wire signed	[7:0]	partial_sum_2	[0:1];
wire signed	[7:0]	partial_sum_3	;
reg	 signed [31:0]	partial_sum_r;

data_writer
    #(
        .B(B)
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
    end 
    else begin    
        
        if(start) begin
            partial_sum_r <= 0;
        end
        else if (mem_we) begin   
            partial_sum_r <= partial_sum_r + partial_sum_3;
        end   
    end
end    


generate
genvar i0;
	for (i0=0; i0 < 8; i0=i0+1) begin : GEN_i0
        assign byte_arr_signed[i0] = mem_di[i0*8 +: 8]; // == mem_di[(i+1)*16-1:i*16]
	end
endgenerate 


generate
genvar i1;
	for (i1=0; i1 < 4; i1=i1+1) begin : GEN_i1
        assign partial_sum_1[i1] = byte_arr_signed[2 * i1] + byte_arr_signed[2 * i1 + 1]; 
	end
endgenerate 


generate
genvar i2;
	for (i2=0; i2 < 2; i2=i2+1) begin : GEN_i2
        assign partial_sum_2[i2] = partial_sum_1[2 * i2] + partial_sum_1[2 * i2 + 1]; 
	end
endgenerate 

assign partial_sum_3 = partial_sum_2[0] + partial_sum_2[1];





assign partial_sum = partial_sum_r;

endmodule
