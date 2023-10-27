module dsp_group
    #(
        parameter N_MUL = 3
    )
    (
        input wire               clk		     ,    
        input wire               rstn           ,     

        input wire [16*N_MUL-1:0]  wei,
        input wire [16*N_MUL-1:0]  fm,

        input wire               WSTART_REG ,
        input wire               RSTART_REG, 
        
        output wire [15:0]       res
    );


reg [16*N_MUL-1:0] wei_r;
reg [16*N_MUL-1:0] fm_r ;

wire signed [16*N_MUL-1:0] prod_i;
reg [16*N_MUL-1:0] prod_r;

wire [15:0] partial_sum;

wire [15:0] res_i;
reg [15:0] res_r;


always @( posedge clk )
begin
    if ( rstn == 1'b0 ) begin
        wei_r  <= 0;
        fm_r <= 0;
        res_r <= 0;
        prod_r <= 0;
    end 
    else begin    

        wei_r <= wei; 
        fm_r  <= fm ;

        prod_r <= prod_i;
        res_r <= res_i;
    end
end    


wire signed [24:0] A_IN  [0:N_MUL-1];
wire signed [17:0] B_IN  [0:N_MUL-1];
wire signed [47:0] P_OUT [0:N_MUL-1];





generate
genvar j;
	for (j=0; j < N_MUL; j=j+1) begin : GEN_j           
        
        assign A_IN[j] = { {9{wei_r[16*(j+1) - 1]}}, wei_r[j*16+:16] };
        assign B_IN[j] = { {2{fm_r[16* (j+1) - 1]}}, fm_r[ j*16+:16] };;
        assign prod_i[j*16+:16] = P_OUT[j][9+:16];

	end
endgenerate 



generate
genvar i;
	for (i=0; i < N_MUL; i=i+1) begin : GEN_i

        DSP48E1 #(
            // Feature Control Attributes: Data Path Selection
            .A_INPUT("DIRECT"),               // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
            .B_INPUT("DIRECT"),               // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
            .USE_DPORT("FALSE"),              // Select D port usage (TRUE or FALSE)
            .USE_MULT("MULTIPLY"),            // Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
            .USE_SIMD("ONE48"),               // SIMD selection ("ONE48", "TWO24", "FOUR12")

            // Pattern Detector Attributes: Pattern Detection Configuration
            .AUTORESET_PATDET("NO_RESET"),    // "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
            .MASK(48'h3fffffffffff),          // 48-bit mask value for pattern detect (1=ignore)
            .PATTERN(48'h000000000000),       // 48-bit pattern match for pattern detect
            .SEL_MASK("MASK"),                // "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
            .SEL_PATTERN("PATTERN"),          // Select pattern value ("PATTERN" or "C")
            .USE_PATTERN_DETECT("NO_PATDET"), // Enable pattern detect ("PATDET" or "NO_PATDET")

            // Register Control Attributes: Pipeline Register Configuration
            .ACASCREG(1),                     // Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
            .ADREG(1),                        // Number of pipeline stages for pre-adder (0 or 1)
            .ALUMODEREG(1),                   // Number of pipeline stages for ALUMODE (0 or 1)
            
            .AREG(2),                         //* Number of pipeline stages for A (0, 1 or 2)
            
            .BCASCREG(1),                     // Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
            
            .BREG(2),                         //* Number of pipeline stages for B (0, 1 or 2)
            
            .CARRYINREG(1),                   // Number of pipeline stages for CARRYIN (0 or 1)
            .CARRYINSELREG(1),                // Number of pipeline stages for CARRYINSEL (0 or 1)
            .CREG(1),                         // Number of pipeline stages for C (0 or 1)
            .DREG(1),                         // Number of pipeline stages for D (0 or 1)
            .INMODEREG(1),                    //* Number of pipeline stages for INMODE (0 or 1)
            .MREG(1),                         //* Number of multiplier pipeline stages (0 or 1)
            .OPMODEREG(1),                    //* Number of pipeline stages for OPMODE (0 or 1)
            .PREG(1)                          //* Number of pipeline stages for P (0 or 1)
        )
        DSP48E1_inst (
                // Cascade: 30-bit (each) output: Cascade Ports
                .ACOUT(),                   // 30-bit output: A port cascade output
                .BCOUT(),                   // 18-bit output: B port cascade output
                .CARRYCASCOUT(),     // 1-bit output: Cascade carry output
                .MULTSIGNOUT(),       // 1-bit output: Multiplier sign cascade output
                .PCOUT(),                   // 48-bit output: Cascade output
                // Control: 1-bit (each) output: Control Inputs/Status Bits
                .OVERFLOW(),             // 1-bit output: Overflow in add/acc output
                .PATTERNBDETECT(), // 1-bit output: Pattern bar detect output
                .PATTERNDETECT(),   // 1-bit output: Pattern detect output
                .UNDERFLOW(),           // 1-bit output: Underflow in add/acc output

                // Data: 4-bit (each) output: Data Ports

                .CARRYOUT(),             // 4-bit output: Carry output

                .P(P_OUT[i]),                           //* 48-bit output: Primary data output
                // Cascade: 30-bit (each) input: Cascade Ports
                .ACIN(30'b0),                     // 30-bit input: A cascade data input
                .BCIN(18'b0),                     // 18-bit input: B cascade input
                .CARRYCASCIN(1'b0),       // 1-bit input: Cascade carry input
                .MULTSIGNIN(1'b0),         // 1-bit input: Multiplier sign input

                // not used.
                .PCIN(48'b0),                     // 48-bit input: P cascade input

                // Control: 4-bit (each) input: Control Inputs/Status Bits

                //* set to 4'b0000 to be Z + X + Y + CIN. 
                    // CIN == 0 when CARRYIN == 1'b0 and CARRYINSEL==3'b0; 
                    // Z == C when OPMODE=7'b011xxxx.
                .ALUMODE(4'b0000),               // 4-bit input: ALU control input

                // CIN == 0 when CARRYIN == 1'b0 and CARRYINSEL==3'b0; 
                .CARRYINSEL(3'b0),               //* 3-bit input: Carry select input

                .CLK(clk),                       //* 1-bit input: Clock input

                // 5'b00000: use A2, B2. Need set USE_DPORT to "FALSE".
                .INMODE(5'b00000),               //* 5-bit input: INMODE control input

                // set OPMODE=7'b011xxxx to make Z == C.
                // set OPMODE=7'bxxx0101 to make X == M, Y == M (M: partial product).
                .OPMODE(7'b0110101),                 //* 7-bit input: Operation mode input

                // Data: 30-bit (each) input: Data Ports


                // A_IN: 25-bits.
                .A({5'b0,A_IN[i]}),                 //* 30-bit input: A data input

                .B(B_IN[i]),                           //* 18-bit input: B data input

                // need to set OPMODE=7'b011xxxx to make Z == C.
                .C(48'b0),                           // 48-bit input: C data input


                .CARRYIN(1'b0),               // 1-bit input: Carry input signal

                // not used.
                .D(25'b0),                           // 25-bit input: D data input

                // Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
                
                .CEA1     (1'b1),           // 1-bit input: Clock enable input for 1st stage AREG
                .CEA2     (1'b1),           // 1-bit input: Clock enable input for 2nd stage AREG
                .CEAD     (1'b1),           // 1-bit input: Clock enable input for ADREG
                .CEALUMODE(1'b1),           // 1-bit input: Clock enable input for ALUMODE
                .CEB1     (1'b1),           // 1-bit input: Clock enable input for 1st stage BREG
                .CEB2     (1'b1),           // 1-bit input: Clock enable input for 2nd stage BREG
                .CEC      (1'b1),           // 1-bit input: Clock enable input for CREG
                .CECARRYIN(1'b1),           // 1-bit input: Clock enable input for CARRYINREG
                .CECTRL   (1'b1),           // 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
                .CED      (1'b1),           // 1-bit input: Clock enable input for DREG
                .CEINMODE (1'b1),           // 1-bit input: Clock enable input for INMODEREG
                .CEM      (1'b1),           // 1-bit input: Clock enable input for MREG
                .CEP      (1'b1),           // 1-bit input: Clock enable input for PREG
                
                
                .RSTA(~rstn),                     // 1-bit input: Reset input for AREG
                .RSTALLCARRYIN(~rstn),   // 1-bit input: Reset input for CARRYINREG
                .RSTALUMODE(~rstn),         // 1-bit input: Reset input for ALUMODEREG
                .RSTB(~rstn),                     // 1-bit input: Reset input for BREG
                .RSTC(~rstn),                     // 1-bit input: Reset input for CREG
                .RSTCTRL(~rstn),               // 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
                .RSTD(~rstn),                     // 1-bit input: Reset input for DREG and ADREG
                .RSTINMODE(~rstn),           // 1-bit input: Reset input for INMODEREG
                .RSTM(~rstn),                     // 1-bit input: Reset input for MREG
                .RSTP(~rstn)                      // 1-bit input: Reset input for PREG
        );

        // End of DSP48E1_inst instantiation
                        
                    
	end
endgenerate 


assign partial_sum = prod_r[0*16 +: 16] + prod_r[1*16 +: 16];
assign res_i = partial_sum + prod_r[2*16 +: 16];
assign res = res_r;


endmodule
