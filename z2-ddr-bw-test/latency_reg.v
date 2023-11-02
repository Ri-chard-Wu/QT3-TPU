

module latency_reg #(
		parameter N = 2,	// Latency.
		parameter B = 8	// Data width.
	)
	(
		input 	wire 		    rstn	,
		input 	wire 		    clk		,
		input 	wire 		    clk_en  ,

		input	wire [B-1:0]	din		,
		output	wire [B-1:0]	dout
	);


reg [B-1:0]	shift_r [0:N-1];


always @(posedge clk) begin
	if (~rstn) begin
		shift_r	[0]	<= 0;
	end
	else begin
		if (clk_en == 1'b1)
			shift_r	[0] <= din;
	end
end

generate
genvar i;
	for (i=1; i<N; i=i+1) begin : GEN_reg
		always @(posedge clk) begin
			if (~rstn) begin
				shift_r	[i]	<= 0;
			end
			else begin
				if (clk_en == 1'b1)
					shift_r	[i] <= shift_r[i-1];
			end
		end
	end
endgenerate


assign dout = (N == 0) ? din : shift_r[N-1];

endmodule

