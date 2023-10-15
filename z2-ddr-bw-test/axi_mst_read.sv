module axi_mst_read
	#(
		// Parameters of AXI Master I/F.

		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64 		,
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
		input	wire	[31:0]				LENGTH_REG		,
		output	wire                        RIDLE_REG  	,

		output wire [5 * 32 - 1:0] probe
    );

/*************/
/* Internals */
/*************/

// Maximum burst size (4kB boundary).

// BYTES_PER_AXI_TRANSFER: in byte.
// DATA_WIDTH: in bits.
localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH / 8;


// States.
typedef enum	{	INIT_ST			,
					START_ST		,
					READ_REGS_ST	,
					ADDR_ST			,
					DATA_ST			,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;


reg [31:0] pv_1;
reg [31:0] pv_2;
reg [31:0] pv_3;


// FSM Signals.
reg read_regs_state		;
reg start_state		    ;
reg data_state ;
reg end_state  ;

// START_REG resync. 
// wire				start_reg_resync	;


// Registers.
reg		[31:0]		addr_reg_r			;
reg		[31:0]		len_reg_r	        ;

// Fifo.
wire				fifo_full			;
wire				fifo_empty			;

// AXI Master.
reg					axi_arvalid_i		;

// Address.
wire	[31:0]		addr_base			;

// Burst length.
wire	[B_BURST_LENGTH - 1:0]		burst_length		;

/****************/
/* Architecture */
/****************/

// // start_reg_resync.
// synchronizer_n start_reg_resync_i
// 	(
// 		.rstn	    (rstn				),
// 		.clk 		(clk				),
// 		.data_in	(START_REG			),
// 		.data_out	(start_reg_resync	)
// 	);

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

// Burst lenth.
assign burst_length		= len_reg_r - 1;

// Base address.
assign addr_base		= addr_reg_r;

// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state		<= INIT_ST;
		
		// Registers.
		addr_reg_r	<= 0;
		len_reg_r	<= 0;

		pv_1	<= 0;
		pv_2	<= 0;
		pv_3	<= 0;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				state <= START_ST;

			START_ST:
				if (START_REG == 1'b1)
					state <= READ_REGS_ST;

			READ_REGS_ST:
				state <= ADDR_ST;

			ADDR_ST:
				if (m_axi_arready == 1'b1)
					state <= DATA_ST;
			DATA_ST:
				if (m_axi_rvalid == 1'b1 && m_axi_rlast == 1'b1 && fifo_full == 1'b0)
					state <= END_ST;

			END_ST:
				if (START_REG == 1'b0)
					state <= START_ST;
		endcase
	
		

		// Registers.
		if (read_regs_state == 1'b1) begin
			addr_reg_r	<= ADDR_REG;
			len_reg_r	<= LENGTH_REG;
		end
		// else if (axi_arvalid_i == 1'b1) begin
		// 	pv_1 <= pv_1;
		// end
		// else if (data_state == 1'b1) begin
		// 	pv_1 <= pv_1 + 1;
		// end
		if (end_state == 1'b1) begin
			pv_2 <= pv_2 + 1;
		end	




		if(m_axi_arready == 1'b1) begin
			pv_1 <= m_axi_araddr;
		end	


		if(m_axi_rvalid == 1'b1) begin
			
			pv_3 <= pv_3 + 1;
		end

	end	
end

// Read Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_arid	= 6'b000000;

// Burst length (must substract 1).
assign m_axi_arlen	= burst_length;

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
	axi_arvalid_i	= 1'b0;
	data_state = 1'b0;
	end_state  = 1'b0;

    case (state)
		//INIT_ST:

		START_ST:
			start_state = 1'b1;

		READ_REGS_ST:
			read_regs_state	= 1'b1;

		ADDR_ST:
			axi_arvalid_i	= 1'b1;

		DATA_ST:
			data_state	= 1'b1;

		END_ST:
			end_state	= 1'b1;
    endcase
end

// Assign outputs.
assign m_axi_araddr	 = addr_base;
assign m_axi_arvalid = axi_arvalid_i;

assign m_axis_tstrb	 = '1;
assign m_axis_tlast	 = 1'b0;

assign RIDLE_REG = start_state;


assign probe[2 * 32 +: 32] = pv_1; // reg7
assign probe[3 * 32 +: 32] = pv_2; // reg8
assign probe[4 * 32 +: 32] = pv_3; // reg9
endmodule

