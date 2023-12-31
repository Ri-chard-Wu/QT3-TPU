module axi_mst_read
	#(
		// Parameters of AXI Master I/F.

		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64 		,
		parameter BURST_LENGTH				= 7,
		parameter  B_BURST_LENGTH            = 4   	
	)
    (
		input	wire						clk				,
		input	wire						rstn			,
		
		// AXI Master Interface.
		output	wire	[ID_WIDTH-1:0]		m_axi_arid		,
		output	wire	[31:0]				m_axi_araddr	,
		output	wire	[B_BURST_LENGTH - 1:0]				m_axi_arlen		,
		output	wire	[2:0]				m_axi_arsize	,
		output	wire	[1:0]				m_axi_arburst	,
		output	wire	[1:0]				m_axi_arlock	,
		output	wire	[3:0]				m_axi_arcache	,
		output	wire	[2:0]				m_axi_arprot	,
		output	wire	[3:0]				m_axi_arqos		,
		output	wire						m_axi_arvalid	,
		input	wire						m_axi_arready	,

		input	wire	[ID_WIDTH-1:0]		m_axi_rid		,
		input	wire	[DATA_WIDTH-1:0]	m_axi_rdata		,
		input	wire	[1:0]				m_axi_rresp		,
		input	wire						m_axi_rlast		,
		input	wire						m_axi_rvalid	,
		output	wire						m_axi_rready	,
		
		// AXIS Master Interfase.
		output	wire						m_axis_tvalid	,
		output	wire	[DATA_WIDTH-1:0]	m_axis_tdata	,
		output	wire	[DATA_WIDTH/8-1:0]	m_axis_tstrb	,
		output	wire						m_axis_tlast	,
		input	wire						m_axis_tready	,
		
		// Registers.
		input	wire						START_REG		,
		input	wire	[31:0]				ADDR_REG		,
		input	wire	[31:0]				NBURST_REG      ,
		output	wire                        DONE_REG     	,

		// output wire     [31:0] 				RNEXT_ADDR

		output wire [5 * 32 - 1:0] probe
    );

/*************/
/* Internals */
/*************/


// States.
typedef enum	{	INIT_ST			,
					START_ST		,
					READ_REGS_ST	,
					INCR_ADDR_ST    ,
					ADDR_ST			,
					DATA_ST			,
					NBURST_ST       ,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;


reg [31:0] pv_1;
reg [31:0] pv_2;
reg [31:0] pv_3;


// FSM Signals.
reg start_state		    ;
reg read_regs_state		;
reg incr_addr_state     ;
reg data_state          ;
reg end_state           ;



// Registers.
reg		[31:0]		addr_reg_r			;
reg		[31:0]		nburst_reg_r	    ;

reg		[31:0]		cnt_nburst    	    ;
wire    [31:0]		addr_acc	        ;


// Fifo.
wire				fifo_full			;
wire				fifo_empty			;

// AXI Master.
reg					axi_arvalid_i		;


/****************/
/* Architecture */
/****************/


// Single-clock fifo.
fifo_axi
    #(
		// Data width.
		.B(DATA_WIDTH	),
		
		// Fifo depth.
		.N(16			)
    )
	fifo_i
    ( 
		.rstn	(rstn			),
		.clk 	(clk			),
		
		// Write I/F.
		.wr_en  (m_axi_rvalid	),
		.din    (m_axi_rdata	),
		
		// Read I/F.
		.rd_en  (m_axis_tready	),
		.dout   (m_axis_tdata	),
		
		// Flags.
		.full	(fifo_full		),
		.empty  (fifo_empty		)
    );

assign m_axi_rready		= ~fifo_full;
assign m_axis_tvalid	= ~fifo_empty;


localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH / 8; 
localparam BYTES_PER_BURST			= (BURST_LENGTH + 1) * BYTES_PER_AXI_TRANSFER;

assign addr_acc	= addr_reg_r + BYTES_PER_BURST;

// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state		<= INIT_ST;
		
		// Registers.
		addr_reg_r	    <= 0;
		nburst_reg_r	<= 0;
		cnt_nburst      <= 0;

	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				state <= START_ST;

			START_ST:
				if (START_REG == 1'b1)
					state <= READ_REGS_ST;

			READ_REGS_ST: // latch addr and assign to m_axi_araddr, and latch nburst.
				state <= ADDR_ST;

			INCR_ADDR_ST: // latch the incrmented addr and assign to m_axi_araddr.
				state <= ADDR_ST;

			ADDR_ST: // set m_axi_arvalid to 1 and wait slave to be ready.
				if (m_axi_arready == 1'b1)
					state <= DATA_ST;
					
			DATA_ST: // read data.
				if (m_axi_rvalid == 1'b1 && m_axi_rlast == 1'b1 && fifo_full == 1'b0)
					state <= NBURST_ST;

			NBURST_ST: // check whether have more read bursts to perform.		 	
				if (cnt_nburst == nburst_reg_r)
					state <= END_ST;
				else
					state <= INCR_ADDR_ST;

			END_ST:
				if (START_REG == 1'b0)
					state <= START_ST;
		endcase
	
		

		// Registers.
		if (read_regs_state == 1'b1) begin
			addr_reg_r	    <= ADDR_REG;
			nburst_reg_r	<= NBURST_REG;
		end
		else if (incr_addr_state == 1'b1) begin
			addr_reg_r	    <= addr_acc;
			nburst_reg_r	<= nburst_reg_r;
		end


		if (read_regs_state == 1'b1)
			cnt_nburst <= 0;
		else if (m_axi_rvalid == 1'b1 && m_axi_rlast == 1'b1 && fifo_full == 1'b0)
			cnt_nburst <= cnt_nburst + 1;	

	end	
end

// Read Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_arid	= 6'b000000;

// Burst length (must substract 1).
assign m_axi_arlen	= BURST_LENGTH;

// Size set to transfer complete data bits per beat (64 bytes/transfer).
assign m_axi_arsize	=	(BYTES_PER_AXI_TRANSFER == 1	)?	3'b000	:
						(BYTES_PER_AXI_TRANSFER == 2	)?	3'b001	:
						(BYTES_PER_AXI_TRANSFER == 4	)?	3'b010	:
						(BYTES_PER_AXI_TRANSFER == 8	)?	3'b011	:
						(BYTES_PER_AXI_TRANSFER == 16	)?	3'b100	:
						(BYTES_PER_AXI_TRANSFER == 32	)?	3'b101	:
						(BYTES_PER_AXI_TRANSFER == 64	)?	3'b110	:
						(BYTES_PER_AXI_TRANSFER == 128	)?	3'b111	:
															3'b000	;

// Set arburst to INCR type.
assign m_axi_arburst	= 2'b01;

// Normal access.
assign m_axi_arlock 	= 2'b00;

// Device Non-bufferable.
assign m_axi_arcache	= 4'b0000;

// Data, non-secure, unprivileged.
assign m_axi_arprot 	= 3'b000;

// Not-used qos.
assign m_axi_arqos		= 4'b0000;

// FSM outputs.
always_comb begin

	// Default.
	start_state	    = 1'b0;
	read_regs_state	= 1'b0;
	incr_addr_state	= 1'b0;
	axi_arvalid_i	= 1'b0;
	data_state = 1'b0;
	end_state  = 1'b0;

    case (state)
		//INIT_ST:

		START_ST:
			start_state = 1'b1;

		READ_REGS_ST:
			read_regs_state	= 1'b1;

		INCR_ADDR_ST:
			incr_addr_state	= 1'b1;

		ADDR_ST:
			axi_arvalid_i	= 1'b1;

		DATA_ST:
			data_state	= 1'b1;

		END_ST:
			end_state	= 1'b1;
    endcase
end

// Assign outputs.
assign m_axi_araddr	 = addr_reg_r;
assign m_axi_arvalid = axi_arvalid_i;

assign m_axis_tstrb	 = '1;
assign m_axis_tlast	 = 1'b0;

assign DONE_REG = end_state;


// assign probe[2 * 32 +: 32] = pv_1; // reg7
// assign probe[3 * 32 +: 32] = cnt_nburst; // reg8
// assign probe[4 * 32 +: 32] = pv_3; // reg9
endmodule

