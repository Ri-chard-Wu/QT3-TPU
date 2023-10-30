
module axi_mst_write
    #(

		parameter ID_WIDTH					= 6				,
		parameter DATA_WIDTH				= 64			,
		parameter ADDR_WIDTH				= 32			,
		parameter BURST_LENGTH				= 7,
		parameter  B_BURST_LENGTH            = 4   
    )
    (
        input	wire						clk   			,
        input	wire						rstn 			,

		// AXI Master Interface.
		output	wire	[ID_WIDTH-1:0]		m_axi_awid		,
		output	wire	[31:0]				m_axi_awaddr	,
		output	wire	[B_BURST_LENGTH - 1:0]				m_axi_awlen		,
		output	wire	[2:0]				m_axi_awsize	,
		output	wire	[1:0]				m_axi_awburst	,
		output	wire	[1:0]				m_axi_awlock	,
		output	wire	[3:0]				m_axi_awcache	,
		output	wire	[2:0]				m_axi_awprot	,
		output	wire	[3:0]				m_axi_awqos		,
		output	wire						m_axi_awvalid	,
		input	wire						m_axi_awready	,

		output	wire	[ID_WIDTH-1:0]		m_axi_wid		,
		output	wire	[DATA_WIDTH-1:0]	m_axi_wdata		,
		output	wire	[DATA_WIDTH/8-1:0]	m_axi_wstrb		,
		output	wire						m_axi_wlast		,
		output	wire						m_axi_wvalid	,
		input	wire						m_axi_wready	,

		input	wire	[ID_WIDTH-1:0]		m_axi_bid		,
		input	wire	[1:0]				m_axi_bresp		,
		input	wire						m_axi_bvalid	,
		output	wire						m_axi_bready	,

		// AXIS Slave Interfase.
		output	wire							    s_axis_tready	,
		input	wire	[DATA_WIDTH+ADDR_WIDTH-1:0]	s_axis_tdata	,
		input	wire	[DATA_WIDTH/8-1:0]		    s_axis_tstrb	,
		input	wire							    s_axis_tlast	,
		input	wire							    s_axis_tvalid	,

		// Registers.
		input	wire						START_REG		,
		input	wire	[31:0]				ADDR_REG		,
		input	wire	[31:0]				NBURST_REG,
        input	wire           				IDLE_REG  	
    );

// Maximum burst size (4kB boundary).

// BYTES_PER_AXI_TRANSFER: in byte.
// DATA_WIDTH: in bits.
localparam BYTES_PER_AXI_TRANSFER	= DATA_WIDTH / 8; 
localparam BYTES_PER_BURST			= (BURST_LENGTH + 1) * BYTES_PER_AXI_TRANSFER;

/*************/
/* Internals */
/*************/

// States.
typedef enum 	{	INIT_ST			,
					TRIGGER_ST		,
					READ_FIFO_ST	,
					INIT_ADDR_ST	,
                	INCR_ADDR_ST	,
                	ADDR_ST			,
                	DATA_ST			,
                	RESP_ST			,
					NBURST_ST		,
					END_ST
				} state_t;

// State register.
(* fsm_encoding = "one_hot" *) state_t state;

// FSM Signals.
reg 						init_state          ;
reg 						read_fifo_state
reg 						init_addr_state		;
reg							addr_state			;
reg							data_state			;
reg							resp_state			;




// Fifo signals.
wire					  		    fifo_rd_en			;
wire	[DATA_WIDTH+ADDR_WIDTH-1:0]	fifo_dout			;
reg		[DATA_WIDTH+ADDR_WIDTH-1:0]	fifo_dout_r			;
wire								fifo_full	        ;
wire								fifo_empty    		;
reg									fifo_empty_r		;


reg		[ADDR_WIDTH-1:0]				addr_r	;
reg		[DATA_WIDTH-1:0]				data_r	;



/****************/
/* Architecture */
/****************/




// Single-clock fifo.
fifo_axi
    #(
		// Data width.
		.B(DATA_WIDTH	),
		
		// Fifo depth.
		.N(32			)
    )
	data_fifo_i
    ( 
		.rstn	(rstn			),
		.clk 	(clk			),
		
		// Write I/F.
		.wr_en	(s_axis_tvalid	),
		.din	(s_axis_tdata[DATA_WIDTH-1:0]	),
		
		// Read I/F.
		.rd_en	(fifo_rd_en		),
		.dout	(fifo_dout[DATA_WIDTH-1:0]		),
		
		// Flags.
		.full	(fifo_full		),
		.empty	(fifo_empty		)
    );



// Single-clock fifo.
fifo_axi
    #(
		// Data width.
		.B(ADDR_WIDTH	),
		
		// Fifo depth.
		.N(32			)
    )
	addr_fifo_i
    ( 
		.rstn	(rstn			),
		.clk 	(clk			),
		
		// Write I/F.
		.wr_en	(s_axis_tvalid	),
		.din	(s_axis_tdata[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH]	),
		
		// Read I/F.
		.rd_en	(fifo_rd_en		),
		.dout	(fifo_dout[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH]		),
		
		// // Flags.
		// .full	(		),
		// .empty	(		)
    );


// Fifo connections.
// assign fifo_rd_en		= m_axi_wready & data_state;
assign fifo_rd_en		= read_fifo_state;
assign s_axis_tready 	= ~fifo_full;

// Write Address Channel.
// Same ID for all transactions (execute them in order).
assign m_axi_awid	= 6'b000000;
assign m_axi_wid = 6'b000000;

// Burst size (transactions).
assign m_axi_awlen	= BURST_LENGTH;

// Size set to transfer complete data bits per beat.
assign m_axi_awsize	=	(BYTES_PER_AXI_TRANSFER == 1	)?	3'b000	:
						(BYTES_PER_AXI_TRANSFER == 2	)?	3'b001	:
						(BYTES_PER_AXI_TRANSFER == 4	)?	3'b010	:
						(BYTES_PER_AXI_TRANSFER == 8	)?	3'b011	:
						(BYTES_PER_AXI_TRANSFER == 16	)?	3'b100	:
						(BYTES_PER_AXI_TRANSFER == 32	)?	3'b101	:
						(BYTES_PER_AXI_TRANSFER == 64	)?	3'b110	:
						(BYTES_PER_AXI_TRANSFER == 128	)?	3'b111	:
															3'b000	;

// Set arburst to INCR type.
assign m_axi_awburst 	= 2'b01;

// Normal access.
assign m_axi_awlock	 	= 2'b00;

// Device Non-bufferable.
assign m_axi_awcache	= 4'b0000;

// Data, non-secure, unprivileged.
assign m_axi_awprot		= 3'b000;


// Not-used qos.
assign m_axi_awqos		= 4'b0000;

// Write Data Channel.
// All bytes are written.
assign m_axi_wstrb 		= '1;


// Registers.
always @(posedge clk) begin
	if (rstn == 1'b0) begin
		// State register.
		state			<= INIT_ST;
		
		addr_r			<= 0;
		data_r			<= 0;

		// Fifo signals.
		fifo_dout_r		<= 0;
		fifo_empty_r	<= 1;
	end
	else begin
		// State register.
		case (state)
			INIT_ST:
				if (~fifo_empty)
					state <= READ_FIFO_ST;			

			READ_FIFO_ST: 
				state <= INIT_ADDR_ST;


			INIT_ADDR_ST:
				state <= ADDR_ST;

			ADDR_ST: // wait for slave to receive the addr (addr_r) we just sent.
				if (m_axi_awready == 1'b1)
					state <= DATA_ST;

			DATA_ST: // perform BURST_LENGTH number of axi transfers. 
				if (  (m_axi_wready == 1'b1) && (m_axi_wvalid == 1'b1) )
					state <= RESP_ST;

			RESP_ST: // wait response from slave
				if (m_axi_bvalid == 1'b1)
					if (~fifo_empty)
						state <= READ_FIFO_ST;		
					else 		
						state <= INIT_ST;
		endcase
		
		// Address generation.
		if (init_addr_state == 1'b1) begin// latch data and addr from fifo.
			addr_r	<= fifo_dout_r[DATA_WIDTH+ADDR_WIDTH-1:DATA_WIDTH];
			data_r  <= fifo_dout_r[DATA_WIDTH-1:0];
		end
		
		// Fifo signals.
		if (fifo_rd_en == 1'b1) begin
			fifo_dout_r		<= fifo_dout;
			fifo_empty_r 	<= fifo_empty;
		end
    end
end



// FSM outputs.
always_comb begin
	// Default.
	init_state		    = 1'b0;
	read_fifo_state		= 1'b0;
	init_addr_state		= 1'b0;
	addr_state			= 1'b0;
	data_state			= 1'b0;
	resp_state			= 1'b0;

    case (state)
		INIT_ST:
			init_state = 1'b1;

		READ_FIFO_ST:
			read_fifo_state	= 1'b1;

		INIT_ADDR_ST:
			init_addr_state	= 1'b1;

		ADDR_ST:
			addr_state		= 1'b1;

		DATA_ST:
			data_state		= 1'b1;

		RESP_ST:
			resp_state		= 1'b1;

    endcase
end

// Assign outputs.
assign m_axi_awaddr		= addr_r;
assign m_axi_awvalid	= addr_state;

assign m_axi_wdata		= data_r;
assign m_axi_wlast		= 1'b1;
assign m_axi_wvalid		= ~fifo_empty_r & data_state;

assign m_axi_bready		= resp_state;

endmodule

