module addr_gen
    #(
       
		parameter UNIT_BURSTS = 128,  // need to be power of 2.
        parameter DATA_WIDTH = 64,
		parameter BURST_LENGTH = 15         
    )
    (
        input wire        clk ,    
        input wire        rstn, 

        input wire  [63:0] cfg      ,

        input wire        latch_en,
        input wire        incr_en ,
        input wire        mem_we  ,

        output wire [31:0] addr     ,
        output wire [31:0] nbursts  ,

        output wire       pending,
        output wire       done,
        output wire [3:0] cu_sel
    );



	localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH / 8; // 8 bytes.
	localparam BYTES_PER_BURST			= (BURST_LENGTH + 1) * BYTES_PER_AXI_TRANSFER; // 16 * 8 = 128 bytes.


    reg [31:0] addr_r 		    ;
    reg [24:0] n_rema_bursts_r  ;
    reg [24:0] n_bursts_r       ;
    reg [31:0] cnt_incr_r       ;
    reg [31:0] cnt_r            ;
    
    reg [3:0]  cu_sel_r;

    wire [31:0] addr_i   ;
    wire [6:0]  nlast_i  ;
    wire [24:0] nbursts_i;
    

    assign addr_i    = cfg[0+:32]; 
    assign nlast_i   = cfg[32+:7]; 
    assign nbursts_i = cfg[39+:18];


    always @( posedge clk )
    begin
        if ( rstn == 1'b0 ) begin
            
            addr_r 		    <= 0;
            n_rema_bursts_r <= 0;  
            n_bursts_r      <= 0;  
            cnt_incr_r      <= 0;  
            cnt_r           <= 0;  

            cu_sel_r          <= 0;

        end 
        else begin    

            if (latch_en == 1'b1) begin // latch

                addr_r 		    <= addr_i;
                n_rema_bursts_r <= nbursts_i;
                n_bursts_r		<= 0;
                cnt_incr_r      <= 0;
            end
            else if (incr_en == 1'b1) begin

                addr_r <= addr_r + (n_bursts_r << ($clog2(BYTES_PER_BURST)));

                if (UNIT_BURSTS >= n_rema_bursts_r) begin // will include the last burst.
                    
                    n_rema_bursts_r <= 0;
                    n_bursts_r		<= n_rema_bursts_r;
                    cnt_incr_r	    <= cnt_incr_r + 
                        ((n_rema_bursts_r - 1) << ($clog2(BYTES_PER_BURST))) + nlast_i; 
                end
                else begin

                    n_rema_bursts_r <= n_rema_bursts_r - UNIT_BURSTS;
                    n_bursts_r		<= UNIT_BURSTS;
                    cnt_incr_r	    <= cnt_incr_r + (UNIT_BURSTS << ($clog2(BYTES_PER_BURST)));
                end	
            end



            if (latch_en == 1'b1) 
                cnt_r <= 0;	
            
            else if (mem_we == 1'b1 && pending == 1'b1) 		
                cnt_r <= cnt_r + BYTES_PER_AXI_TRANSFER;



            if (latch_en == 1'b1) begin
                cu_sel_r <= 0;	
            end
            else if (mem_we == 1'b1 && pending == 1'b1) begin		
        
                // TODO: should be min(N_CONV_UNIT, c1).
                // TODO: consider replace following with local checks in each conv_units: 
                    // pass down sel signal in cyclic order. Since they know whethe themselves are the tail,
                    // so it would be convenit to know when to wrap.
                if (cu_sel_r == N_CONV_UNIT-1) 
                    cu_sel_r <= 0;
                else
                    cu_sel_r <= cu_sel_r + 1;
            end		

        end
    end    

    assign addr    = addr_r    ;
    assign nbursts = n_bursts_r;


    assign pending = (cnt_r == cnt_incr_r) ? 0 : 1;
    assign done   =  (n_rema_bursts_r == 0) ? 1'b1 : 1'b0;

    assign cu_sel = cu_sel_r;
endmodule