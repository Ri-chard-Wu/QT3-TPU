
module ctrl
    #(
        parameter PMEM_N					= 10
    )
    (
		input	wire          clk    ,
		input	wire          rstn	,

		output	wire [PMEM_N-1:0] pmem_addr   ,   
		input	wire [63:0]		  pmem_do     ,

        input	wire [31:0]   DDR_BASEADDR_REG,
		input	wire          START_REG       ,

		output	wire          RSTART_REG	,
		output	wire [31:0]   RADDR_REG		,
		output	wire [31:0]   RNBURST_REG	,
        input	wire          RIDLE_REG  	,

		output	wire          WSTART_REG	,
		output	wire [31:0]   WADDR_REG		,
		output	wire [31:0]   WNBURST_REG	,

        output wire           start,

        output wire [5 * 32 - 1:0] probe
	);


typedef enum{	
    INIT1_ST           , 
    INIT2_ST           ,
    PC_RST1_ST         ,
    PC_RST2_ST         ,   
    DECODE_ST          ,    
    DDR_READ_INIT_ST   ,           
    DDR_READ_DATA_ST   ,           
    ERR_INSTR_ST       ,       
    END_ST     
} state_t;

(* fsm_encoding = "one_hot" *) state_t state;


reg  [63:0] inst_r;

wire [7:0]  opcode;     // 8 bit
wire [31:0] start_addr; // 32 bit
wire [15:0] nburst;        // 16 bit 

assign opcode		    = inst_r[63:56]; 
assign start_addr		= inst_r[55:24] + DDR_BASEADDR_REG;
assign nburst	        = inst_r[23:8];      




reg [31:0] cnt_read_time;
reg [31:0] rx_cnt_r;

reg [31:0] pv_1;

// wire inst_fifo_empty;

wire	[PMEM_N-1:0]	 	pc_i;


reg  init2_state         ;
reg  pc_rst1_state       ;
reg  pc_rst2_state       ;
reg  fetch_state       ;
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
        // inst              <= 64'h0100000000010000; // 0x01 + 0x00000000 + 0x0100 + dont-care's.
		cnt_read_time     <= 0;
        rx_cnt_r          <= 0;
        
		pc_r			<= 0;
		inst_r			<= 0;

        pv_1 <= 0;
	end
	else begin
		
        
		case (state)

			INIT1_ST:
                state <= INIT2_ST;
			
            INIT2_ST:
                if (start_reg_resync == 1'b1)
                    state <= PC_RST1_ST;

			PC_RST1_ST: // In next cycle, tell prog mem that we want the first inst.
				state <= PC_RST2_ST;

			PC_RST2_ST: // Wait one cycle for first inst to come out from prog mem.
				state <= FETCH_ST;

            FETCH_ST:   // In the next cycle: pc_r <= pc_r + 1 and ir_r <= pmem_do.
                state <= DECODE_ST;

            DECODE_ST:
				if ( opcode == 8'b00000001 ) // read
					state <= DDR_READ_INIT_ST;
				else if ( opcode == 8'b00111111 ) // end
					state <= END_ST;                    
                else
                    state <= ERR_INSTR_ST;

            DDR_READ_INIT_ST:
                state <= DDR_READ_DATA_ST;

            DDR_READ_DATA_ST:
                if (RIDLE_REG)
                    state <= DECODE_ST;
                

			ERR_INSTR_ST:
				state <= END_ST;

			END_ST:
				if (start_reg_resync == 1'b0)
					state <= INIT2_ST;
		endcase


		if (init2_state == 1'b1 || end_state == 1'b1) begin   
            cnt_read_time <= cnt_read_time;
		end
        else if (pc_rst2_state == 1'b1) begin
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
            // pv_1 <= pv_1 + 1;
		end     



		if (pc_rst1_state == 1'b1)
			pc_r <= 0;
		else if (fetch_state == 1'b1)
			pc_r <= pc_i;


		if (fetch_state == 1'b1)
			inst_r <= pmem_do;
        
	end	
end


assign pc_i	= pc_r + 1;


// 0x17D784 == 1562500 == 100e6 / 64, where:  
    // 100e6 is total bytes to read.
    // 64 is number of bytes read in each axi transaction.
// assign inst_fifo_empty = (rx_cnt_r ==  24'h17D784) ? 1'b1 : 1'b0;

// assign inst_fifo_empty = 1'b1;



always_comb begin
	
    init2_state         = 1'b0;
    pc_rst1_state       = 1'b0;
    pc_rst2_state       = 1'b0;
    fetch_state         = 1'b0;
    decode_state	    = 1'b0;
    ddr_read_init_state	= 1'b0;
    ddr_read_data_state	= 1'b0;
    end_state           = 1'b0;

    case (state) 
                 
        INIT2_ST: 
            init2_state = 1'b1;

        PC_RST1_ST:
            pc_rst1_state = 1'b1;

        PC_RST2_ST:
            pc_rst2_state = 1'b1;

        FETCH_ST
            fetch_state = 1'b1;


        DECODE_ST:
            decode_state = 1'b1;

        DDR_READ_INIT_ST:
            ddr_read_init_state	= 1'b1;

        DDR_READ_DATA_ST:
            ddr_read_data_state	= 1'b1;

        END_ST:
            end_state	= 1'b1;

    endcase
end










assign RSTART_REG  = ddr_read_init_state;	 
assign RADDR_REG   = start_addr;		
assign RNBURST_REG = {{16{1'b0}}, nburst};

assign start = pc_rst2_state;
assign probe[0 * 32 +: 32] = cnt_read_time;


// Multiply address by 8 to convert from 8-bytes-addressing to byte-addressing.
assign	pmem_addr = {pc_r[PMEM_N-4:0], 3'b000};


endmodule