
module ctrl
    (
		input	wire          clk    ,
		input	wire          rstn	,
        
        input	wire [31:0]   DDR_BASEADDR_REG,
		input	wire          START_REG       ,

		output	wire          RSTART_REG	,
		output	wire [31:0]   RADDR_REG		,
		output	wire [31:0]   RLENGTH_REG	,
        input	wire          RIDLE_REG  	,

		output	wire          WSTART_REG	,
		output	wire [31:0]   WADDR_REG		,
		output	wire [31:0]   WNBURST_REG	,

        output wire           start
	);


typedef enum{	
    INIT1_ST           , 
    INIT2_ST           ,
    START_ST           ,   
    DECODE_ST          ,    
    DDR_READ_INIT_ST   ,           
    DDR_READ_DATA_ST   ,           
    ERR_INSTR_ST       ,       
    END_ST     
} state_t;

(* fsm_encoding = "one_hot" *) state_t state;


reg  [64:0] inst;
wire [7:0]  opcode;     // 8 bit
wire [31:0] start_addr; // 32 bit
wire [3:0]  len;        // 4 bit 

assign opcode		    = inst[63:56]; 
assign start_addr		= inst[55:24] + DDR_BASEADDR_REG;
assign len	        	= inst[23:20];      // number of successive 64-bits data to rd/wr.

reg [31:0] cnt_read_time;
reg [31:0] rx_cnt_r;

wire inst_fifo_empty;



reg  init2_state         ;
reg  start_state        ;
reg  decode_state        ;
reg  ddr_read_init_state;
reg  ddr_read_data_state;
reg  end_state          ;



synchronizer_n start_reg_resync_i
	(
		.rstn	    (rstn				),
		.clk 		(clk				),
		.data_in	(START_REG			),
		.data_out	(start_reg_resync	)
	);

    


// test spec: burst length is 8, burst size is 64-bit.

always @(posedge clk) begin
    
	if (rstn == 1'b0) begin
    
		state		      <= INIT1_ST;
        inst              <= 64'h0100000000800000; // 0x01 + 0x00000000 + 0x8 + dont-care's.
		cnt_read_time     <= 0;
        rx_cnt_r          <= 0;

	end
	else begin
		
        
		case (state)

			INIT1_ST:
                state <= INIT2_ST;
			
            INIT2_ST:
                if (start_reg_resync == 1'b1)
                    state <= START_ST;

			START_ST:
				state <= DECODE_ST;

            DECODE_ST:
				if ( opcode == 8'b00000001 ) // read
					state <= DDR_READ_INIT_ST;
                else
                    state <= ERR_INSTR_ST;

            DDR_READ_INIT_ST:
                state <= DDR_READ_DATA_ST;

            DDR_READ_DATA_ST:
                if (RIDLE_REG & ~inst_fifo_empty)
                    state <= DECODE_ST;
                else if(RIDLE_REG & inst_fifo_empty)
                    state <= END_ST;

			ERR_INSTR_ST:
				state <= END_ST;

			END_ST:
				if (start_reg_resync == 1'b0)
					state <= INIT2_ST;
		endcase


		if (init2_state == 1'b1) begin   
            cnt_read_time <= cnt_read_time;
		end
        else if (start_state == 1'b1) begin
			cnt_read_time <= 0;
        end
		else begin
			cnt_read_time <= cnt_read_time + 1;
		end
        

		if (init2_state == 1'b1) begin   
            rx_cnt_r <= 0;
		end        
		else if (ddr_read_init_state == 1'b1) begin   
            rx_cnt_r <= rx_cnt_r + 1;
		end        

	end	
end


// 0x17D784 == 1562500 == 100e6 / 64, where:  
    // 100e6 is total bytes to read.
    // 64 is number of bytes read in each axi transaction.
// assign inst_fifo_empty = (rx_cnt_r ==  24'h17D784) ? 1'b1 : 1'b0;

assign inst_fifo_empty = 1'b1;



always_comb begin
	
    init2_state         = 1'b0;
    start_state         = 1'b0;
    decode_state	    = 1'b0;
    ddr_read_init_state	= 1'b0;
    ddr_read_data_state	= 1'b0;
    end_state           = 1'b0;

    case (state) 
                 
        INIT2_ST: 
            init2_state = 1'b1;

        START_ST:
            start_state = 1'b1;

        DECODE_ST
            decode_state = 1'b1;

        DDR_READ_INIT_ST:
            ddr_read_init_state	= 1'b1;

        DDR_READ_DATA_ST
            ddr_read_data_state	= 1'b1;

        END_ST:
            end_state	= 1'b1;

    endcase
end


assign RSTART_REG  = ddr_read_init_state;	 
assign RADDR_REG   = start_addr;		
assign RLENGTH_REG = {{28{1'b0}}, len};

endmodule