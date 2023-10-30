module activation_unit
    #(
        parameter N_KERNEL = 4, 
        parameter B_PIXEL = 16,
 
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 

        input wire [2:0]            type    , // relu, silu, sigmiod, tanh, etc.

		input wire [N_KERNEL*2*B_PIXEL:0]  di       ,     
		input wire                         di_valid	,
		output wire [N_KERNEL*2*B_PIXEL:0] do		,		
        output wire                        do_valid   
    );




endmodule