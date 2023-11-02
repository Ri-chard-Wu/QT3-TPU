module strided_buffer
    #(
        parameter N_BUF_X = 5, 
        parameter B_BUF_ADDR = 9,
        parameter B_SHAPE = 25,
        parameter B_COORD = 8,
        parameter DATA_WIDTH = 64,
        parameter N_CONV_UNIT = 8,
		parameter UNIT_BURSTS = 32,  // need to be pow er of 2.
        
    )
    (
        input wire                  clk     ,    
        input wire                  rstn    , 
    
        // #####################
        // # wr
        // #####################
        input wire  [B_SHAPE-1:0]     shape,
        input wire  [6:0]             n_wrap_c_sum,
        
        input wire                    wr_en ,
        input wire [DATA_WIDTH-1:0]   wr_di ,
        output wire                   wr_last,
        output wire                   wr_tog,
        output wire [B_COORD-1:0]     wr_ptr,
        output wire [B_BUF_ADDR-1:0]  wr_base,

    
        // #####################
        // # rd
        // #####################
        input wire          [1:0]    stride,
        input wire          [1:0]    pad ,
        input wire  [B_SHAPE-1:0]    wei_shape,
        input wire  [B_SHAPE-1:0]    ftm_shape,

        input wire                   rd_en   ,
        output wire [DATA_WIDTH-1:0] rd_do   ,        
        output wire                  rd_last ,
        output wire [B_COORD-1:0]    rd_ptr         ,
        input  wire                  rd_base_incr_en,
        output wire [B_BUF_ADDR-1:0] rd_base        
    );

    wire [N_BUF_X-1:0]    wr_sel ;
    wire [DATA_WIDTH-1:0] wr_do  ;
    wire [B_BUF_ADDR:0]   wr_addr;
    wire [B_BUF_ADDR-1:0] wr_base;
    wire [B_COORD-1:0]    wr_ptr ;

    wire [B_BUF_ADDR*N_FTMBUF_X-1:0] rd_addr ;
    wire [3:0]                       rd_sel;


    strided_buffer_writer
        #(
            .N_BUF_X    (N_BUF_X), 
            .B_BUF_ADDR (B_BUF_ADDR),
            .B_SHAPE    (B_SHAPE)  ,
            .DATA_WIDTH (DATA_WIDTH),
            .B_COORD    (B_COORD),
            .N_CONV_UNIT(N_CONV_UNIT),
            .UNIT_BURSTS(UNIT_BURSTS)
        )
        strided_buffer_writer_i
        (
            .clk  (clk	)	     ,    
            .rstn (rstn)         ,     

            .shape        (shape),
            .n_wrap_c_sum (n_wrap_c_sum),

            .wr_di   (wr_di     ),
            .wr_do   (wr_do     ),
            .wr_en   (wr_en     ),
            .wr_sel  (wr_sel    ), 
            .wr_addr (wr_addr   ),
            .wr_last (wr_last   ),
            .wr_tog  (wr_tog    ),  // will toggle whenever one kernel is completly loaded.
            .wr_base (wr_base     ),
            .wr_ptr  (wr_ptr      )
        );


    strided_buffer_reader
        #(
            .N_BUF_X    (N_BUF_X), 
            .B_BUF_ADDR (B_BUF_ADDR),
            .B_SHAPE    (B_SHAPE)  ,
            .DATA_WIDTH (DATA_WIDTH),
            .B_COORD    (B_COORD),
            .N_CONV_UNIT(N_CONV_UNIT),
            .UNIT_BURSTS(UNIT_BURSTS)
        )
        ftm_buffer_reader_i
        (
            .clk  (clk	)	     ,    
            .rstn (rstn)         ,     
            
            .stride(stride   )   ,
            .pad   (pad      )   ,

            .ftm_shape(ftm_shape),
            .wei_shape(wei_shape),

            // TODO: fb_rd_addr and fb_rd_sel may not be synced, need add delay regs.
            // TODO: rd_addr and rd_sel may not be synced, need add delay regs.
            .rd_en    (rd_en       ),
            .rd_addr  (rd_addr  ),        
            .rd_sel   (rd_sel   ),
            .rd_last  (rd_last ),
            .rd_ptr           (rd_ptr             ), // the x-coordinate.
            .rd_base_incr_en  (rd_base_incr_en    ),
            .rd_base          (rd_base            )
        );


    // // TODO: change to 10-to-1 mux.
    // assign rd_do = (0 == rd_sel) ? rd_do_mux[0*DATA_WIDTH+:DATA_WIDTH] :
    //                (1 == rd_sel) ? rd_do_mux[1*DATA_WIDTH+:DATA_WIDTH] :
    //                (2 == rd_sel) ? rd_do_mux[2*DATA_WIDTH+:DATA_WIDTH] :
    //                (3 == rd_sel) ? rd_do_mux[3*DATA_WIDTH+:DATA_WIDTH] :
    //                (4 == rd_sel) ? rd_do_mux[4*DATA_WIDTH+:DATA_WIDTH] : 0; // 0: for padding.


    // not yet implemented.
    mux
        #(
            .N    (N_BUF_X   ), // number of inputs to mux.
            .B    (DATA_WIDTH)  // width of each input.
        )
        mux_i
        (
            .clk  (clk	)	     ,    
            .rstn (rstn)         ,     

            .di   (rd_do_mux),
            .sel  (rd_sel   ),
            .do   (rd_do    )
        );


    // strided write.
    generate
    genvar i;
        for (i=0; i < N_BUF_X; i=i+1) begin : GEN_BUF

            // wrapper for BRAM primitives.
            bram_sdp bram_sdp_i
                (
                    .clk		(clk		                    ),
                    .rstn       (rstn		                    ),

                    .we         (wr_sel[i]                          ),
                    .wraddr     (wr_addr[B_BUF_ADDR-1:0]         ),
                    .di         (wr_do                           )

                    .rdaddr     (rd_addr[i*B_BUF_ADDR+:B_BUF_ADDR] ),
                    .do         (rd_do_mux[i*DATA_WIDTH+:DATA_WIDTH]   ),       
                );

        end
    endgenerate 


endmodule