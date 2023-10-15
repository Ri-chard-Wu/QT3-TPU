module axi_slv
	(
		input  	wire  				s_axi_aclk		,
		input  	wire  				s_axi_aresetn	,

		// Write Address Channel.
		input  	wire	[7:0]		s_axi_awaddr	,
		input  	wire 	[2:0]		s_axi_awprot	,
		input  	wire  				s_axi_awvalid	,
		output	wire  				s_axi_awready	,

		// Write Data Channel.
		input 	wire 	[31:0] 		s_axi_wdata		,
		input 	wire 	[3:0]		s_axi_wstrb		,
		input 	wire  				s_axi_wvalid	,
		output 	wire  				s_axi_wready	,

		// Write Response Channel.
		output 	wire 	[1:0]		s_axi_bresp		,
		output 	wire  				s_axi_bvalid	,
		input 	wire  				s_axi_bready	,

		// Read Address Channel.
		input 	wire 	[7:0] 		s_axi_araddr	,
		input 	wire 	[2:0] 		s_axi_arprot	,
		input 	wire  				s_axi_arvalid	,
		output 	wire  				s_axi_arready	,

		// Read Data Channel.
		output 	wire 	[31:0]		s_axi_rdata		,
		output 	wire 	[1:0]		s_axi_rresp		,
		output 	wire  				s_axi_rvalid	,
		input 	wire  				s_axi_rready	,

		// Registers.
		output	wire	[31:0]    DDR_BASEADDR_REG,
		output	wire            START_REG       ,
    input	  wire  [31:0]    PARTIAL_SUM_REG ,

    input wire [5 * 32 - 1:0] probe
);

// Width of S_AXI data bus
localparam integer C_S_AXI_DATA_WIDTH	= 32;
// Width of S_AXI address bus
localparam integer C_S_AXI_ADDR_WIDTH	= 8;

// AXI4LITE signals
reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
reg  	axi_awready;
reg  	axi_wready;
reg [1 : 0] 	axi_bresp;
reg  	axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
reg  	axi_arready;
reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
reg [1 : 0] 	axi_rresp;
reg  	axi_rvalid;



localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 5;


reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg7;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg8;
reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg9;



wire	 slv_reg_rden;
wire	 slv_reg_wren;
reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
integer	 byte_index;
reg	 aw_en;


assign s_axi_awready	= axi_awready;
assign s_axi_wready	= axi_wready;
assign s_axi_bresp	= axi_bresp;
assign s_axi_bvalid	= axi_bvalid;
assign s_axi_arready	= axi_arready;
assign s_axi_rdata	= axi_rdata;
assign s_axi_rresp	= axi_rresp;
assign s_axi_rvalid	= axi_rvalid;

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_awready <= 1'b0;
      aw_en <= 1'b1;
    end 
  else
    begin    
      if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en)
        begin
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
        end
        else if (s_axi_bready && axi_bvalid)
            begin
              aw_en <= 1'b1;
              axi_awready <= 1'b0;
            end
      else           
        begin
          axi_awready <= 1'b0;
        end
    end 
end       


always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_awaddr <= 0;
    end 
  else
    begin    
      if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en)
        begin
          axi_awaddr <= s_axi_awaddr;
        end
    end 
end       

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end 
  else
    begin    
      if (~axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en )
        begin
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end 
end       

assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      slv_reg0 <= 0;
      slv_reg1 <= 0;
      slv_reg2 <= 0;
      slv_reg3 <= 0;
      slv_reg4 <= 0;
      slv_reg5 <= 0;
      slv_reg6 <= 0;
      slv_reg7 <= 0;
      slv_reg8 <= 0;
      slv_reg9 <= 0;     

    end 
  else begin

    if (slv_reg_wren)
      begin
        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
          6'h00:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                slv_reg0[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end  
          6'h01:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                slv_reg1[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end  
          6'h03:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                slv_reg3[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end  
          6'h04:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( s_axi_wstrb[byte_index] == 1 ) begin
                slv_reg4[(byte_index*8) +: 8] <= s_axi_wdata[(byte_index*8) +: 8];
              end  
           
          default : begin
                      slv_reg0 <= slv_reg0;
                      slv_reg1 <= slv_reg1;
                      slv_reg3 <= slv_reg3;
                      slv_reg4 <= slv_reg4;

                                    
                    end
        endcase
      end



      slv_reg2 <= PARTIAL_SUM_REG;

      slv_reg5 <= probe[0 * 32 +: 32];
      slv_reg6 <= probe[1 * 32 +: 32];
      slv_reg7 <= probe[2 * 32 +: 32];
      slv_reg8 <= probe[3 * 32 +: 32];
      slv_reg9 <= probe[4 * 32 +: 32];
      
  end
end    

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end 
  else
    begin    
      if (axi_awready && s_axi_awvalid && ~axi_bvalid && axi_wready && s_axi_wvalid)
        begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0; // 'OKAY' response 
        end                   // work error responses in future
      else
        begin
          if (s_axi_bready && axi_bvalid) 
            begin
              axi_bvalid <= 1'b0; 
            end  
        end
    end
end   

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 32'b0;
    end 
  else
    begin    
      if (~axi_arready && s_axi_arvalid)
        begin
          axi_arready <= 1'b1;
          axi_araddr  <= s_axi_araddr;
        end
      else
        begin
          axi_arready <= 1'b0;
        end
    end 
end       

always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end 
  else
    begin    
      if (axi_arready && s_axi_arvalid && ~axi_rvalid)
        begin
          // Valid read data is available at the read data bus
          axi_rvalid <= 1'b1;
          axi_rresp  <= 2'b0; // 'OKAY' response
        end   
      else if (axi_rvalid && s_axi_rready)
        begin
          // Read data is accepted by the master
          axi_rvalid <= 1'b0;
        end                
    end
end    

assign slv_reg_rden = axi_arready & s_axi_arvalid & ~axi_rvalid;
always @(*)
begin
      // Address decoding for reading registers
      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
        6'h00   : reg_data_out <= slv_reg0;
        6'h01   : reg_data_out <= slv_reg1;
        6'h02   : reg_data_out <= slv_reg2;
        6'h03   : reg_data_out <= slv_reg3;
        6'h04   : reg_data_out <= slv_reg4;
        6'h05   : reg_data_out <= slv_reg5;
        6'h06   : reg_data_out <= slv_reg6;
        6'h07   : reg_data_out <= slv_reg7;
        6'h08   : reg_data_out <= slv_reg8;
        6'h09   : reg_data_out <= slv_reg9;        
        default : reg_data_out <= 0;
      endcase
end

// Output register or memory read data
always @( posedge s_axi_aclk )
begin
  if ( s_axi_aresetn == 1'b0 )
    begin
      axi_rdata  <= 0;
    end 
  else
    begin    
      if (slv_reg_rden)
        begin
          axi_rdata <= reg_data_out;     // register read data
        end   
    end
end    

assign START_REG = slv_reg0[0];
assign DDR_BASEADDR_REG	= slv_reg1[31:0];
      




endmodule
