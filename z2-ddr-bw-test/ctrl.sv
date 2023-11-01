
module ctrl
    #(
        parameter PMEM_N  = 10,
        parameter FW      = 242
    )
    (
		input	wire          clk    ,
		input	wire          rstn	,

		output	wire [PMEM_N-1:0] pmem_addr   ,   
		input	wire [63:0]		  pmem_do     ,

		input	wire          START_REG       ,

        output wire           start,

		output wire   	      fifo_wr_en	 ,
		output wire [63:0]    fifo_di	     ,
		input  wire           fifo_full 	 ,

        output wire          cfg_valid,
        output wire [FW-1:0] cfg_data ,
        input  wire          cfg_ready
	);


typedef enum{	
    INIT_ST            , 
    PC_RST_ST         ,
    WAIT_INST_ST       ,   
    FETCH_ST 		,
    DECODE_ST          ,    
	REGWI_ST		,
	SET_ST				,
    ERR_INSTR_ST       ,       
    END_ST     
} state_t;

(* fsm_encoding = "one_hot" *) state_t state;

reg pc_rst_i       ;
reg fetch_state    ;
reg	cfg_valid_i    ;
reg end_state      ;
reg ir_en_i		   ;
reg pc_en_i		   ;
reg	reg_wen_i	   ;
reg fifo_wr_en_i   ;



reg  [63:0] ir_r;

wire 	[7:0]       opcode_i;     // 8 bit
wire	[2:0]		page_i;
wire	[17:0]		oper_i;
wire    [31:0] 		imm_i; // 32 bit


wire	[4:0]		reg_addr0_i;
wire	[4:0]		reg_addr1_i;
wire	[4:0]		reg_addr2_i;
wire	[4:0]		reg_addr3_i;
wire	[4:0]		reg_addr4_i;
wire	[4:0]		reg_addr5_i;
wire	[4:0]		reg_addr6_i;


// Write address.
wire	[4:0]		reg_addr7_i;

// Write data.
wire	[B-1:0]		reg_din7_i;

// Output registers.
wire	[B-1:0]		reg_dout0_i;
wire	[B-1:0]		reg_dout1_i;
wire	[B-1:0]		reg_dout2_i;
wire	[B-1:0]		reg_dout3_i;
wire	[B-1:0]		reg_dout4_i;
wire	[B-1:0]		reg_dout5_i;
wire	[B-1:0]		reg_dout6_i;

reg		[63:0]	 	ir_r;


reg     [PMEM_N-1:0]	 	pc_r;
wire	[PMEM_N-1:0]	 	pc_i;




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
    
		state		      <= INIT_ST;
        
		pc_r			<= 0;
		ir_r			<= 0;

	end
	else begin
		 
        
		case (state)

		
            INIT_ST:
                if (start_reg_resync == 1'b1)
                    state <= PC_RST_ST;

			PC_RST_ST: // In next cycle, tell prog mem that we want the first inst.
				state <= WAIT_INST_ST;

			WAIT_INST_ST: // Wait one cycle for first inst to come out from prog mem.
				state <= FETCH_ST;

            FETCH_ST:   // In the next cycle: pc_r <= pc_r + 1 and ir_r <= pmem_do.
                state <= DECODE_ST;

            DECODE_ST:
		
				if ( opcode_i == 8'b00011001 )
					state <= REGWI_ST;
				else if ( opcode_i == 8'b01010001 || opcode_i == 8'b01011000 )
					state <= SET_ST;
				else if ( opcode_i == 8'b00010000 )
					state <= PUSH_ST; 						
				else if ( opcode_i == 8'b00111111 ) 
					state <= END_ST;        
                else
                    state <= ERR_INSTR_ST;

			REGWI_ST:
				state <= DECODE_ST;

			SET_ST:
                if(cfg_ready)
				    state <= FETCH_ST;

			PUSH_ST:
                if(~fifo_full)
				    state <= FETCH_ST;
	
			ERR_INSTR_ST:
				state <= END_ST;

			END_ST:
				if (start_reg_resync == 1'b0)
					state <= INIT_ST;
		endcase



		if (pc_rst_i == 1'b1)
			pc_r <= 0;
		else if (pc_en_i == 1'b1)
			pc_r <= pc_i;


		if (ir_en_i == 1'b1) begin
			ir_r <= pmem_do;
        end
        
	end	
end

assign pc_i	= pc_r + 1;



always_comb begin
	
    pc_rst_i            = 1'b0;
    reg_wen_i           = 1'b0;
    ir_en_i		        = 1'b0;
    pc_en_i			    = 1'b0;
    cfg_valid_i	  		= 1'b0;
    end_state    	    = 1'b0;
    fifo_wr_en_i		= 1'b0;

    case (state) 

        PC_RST_ST:
            pc_rst_i = 1'b1;

        FETCH_ST: begin
			ir_en_i		            = 1'b1;
			pc_en_i		            = 1'b1;
		end
           
		REGWI_ST: begin
			ir_en_i			= 1'b1;
			pc_en_i			= 1'b1;
			reg_wen_i		= 1'b1;
		end

		SET_ST: begin
			// ir_en_i			= 1'b1;
			// pc_en_i			= 1'b1;

			cfg_valid_i	= 1'b1;
		end

		PUSH_ST: begin
			// ir_en_i			= 1'b1;
			// pc_en_i			= 1'b1;

			fifo_wr_en_i	= 1'b1;
		end
		

        END_ST:
            end_state	= 1'b1;

    endcase
end



// Regfile block.
regfile_8p
    #(
        // Data width.
        .B(B)
    )
    regfile_i 
	( 
		// Clock and reset.
        .clk    (clk  	        ),
		.rstn	(rstn	        ),

		// Read address.
        .addr0	(reg_addr0_i	),
		.addr1	(reg_addr1_i	),
        .addr2	(reg_addr2_i	),
		.addr3	(reg_addr3_i	),
		.addr4	(reg_addr4_i	),
		.addr5	(reg_addr5_i	),
		.addr6	(reg_addr6_i	),

		// Write address.
		.addr7	(reg_addr7_i	),

		// Write data.
		.din7	(reg_din7_i		),
		.wen7	(reg_wen_i		),

		// Page number.
		.pnum	(page_i			),

		// Output registers.
		.dout0	(reg_dout0_i	),
		.dout1	(reg_dout1_i	),
		.dout2	(reg_dout2_i	),
		.dout3	(reg_dout3_i	),
		.dout4	(reg_dout4_i	),
		.dout5	(reg_dout5_i	),
		.dout6	(reg_dout6_i	)
    );

// 18 + 32 * 7 = 242
assign cfg_data = 	{	oper_i     , // [28:11]
						reg_dout0_i,
						reg_dout1_i,
						reg_dout2_i,
						reg_dout3_i,
						reg_dout4_i,
						reg_dout5_i,
						reg_dout6_i						
                    };


assign opcode_i		= ir_r[63:56]; // 8-bits
assign page_i		= ir_r[55:53]; // 3-bits
assign oper_i		= ir_r[52:35]; // 18-bits
assign imm_i		= ir_r[31:0];  // 32-bits

// Register address.
assign reg_addr0_i	= ir_r[34:30];
assign reg_addr1_i	= ir_r[29:25];
assign reg_addr2_i	= ir_r[24:20];
assign reg_addr3_i	= ir_r[19:15];
assign reg_addr4_i	= ir_r[14:10];
assign reg_addr5_i	= ir_r[9:5]  ;
assign reg_addr6_i	= ir_r[4:0]  ;

assign reg_addr7_i	= ir_r[45:41];
assign reg_din7_i = imm_i;



assign cfg_valid	= cfg_valid_i;


// reg_dout0_i: ftm addr.
// reg_dout1_i: ftm loading config (n_wrap_c_acc: 7-bits, n_bursts: 18-bits, valid_bytes_in_last_burst: 7-bits).
assign fifo_di    = {reg_dout0_i, reg_dout1_i}; 
assign fifo_wr_en = fifo_wr_en_i;


// Multiply address by 8 to convert from 8-bytes-addressing to byte-addressing.
assign	pmem_addr = {pc_r[PMEM_N-4:0], 3'b000};


endmodule