


// Requirement: 2 * pad + 1 == kernel size.
// Requirement: stride < N_FTMBUF_X.

module conv_unit
    #(
        parameter ID = 0,

        parameter N_DSP_GROUP = 4, 
        parameter N_KERNEL = 4,
        parameter B_PIXEL = 16,
        parameter B_INST = 32,

        parameter B_PARA = 64,
        parameter B_SHAPE = 25,
        
        parameter N_FTMBUF_X = 5,
        parameter N_WEIBUF_X = 1,
            
        parameter B_BUF_ADDR = 9, 
        parameter DATA_WIDTH = 64,
        parameter B_COORD = 8,

        parameter N_CONV_UNIT = 8,

		parameter UNIT_BURSTS_WEI = 32,  // need to be power of 2.
		parameter UNIT_BURSTS_FTM = 1024  // need to be power of 2.	   
    )
    ( 
		// output wire is_tail		              , 

        input  wire                  pipe_en   ,
        input  wire                  pipe_en_i ,
        output wire                  pipe_en_o ,

        input wire                     clk      ,    
        input wire                     rstn      ,     
        
        input  wire [63:0]           cfg_wr_data ,

        input  wire [63:0]           cfg_rd_data,
        output wire                  cfg_rd_done  ,
        input  wire                  cfg_rd_run  ,

        input wire                   wb_we    ,
        output wire                  wb_suff  ,
        output wire                  wb_full  , 
        input wire                   fb_we    ,
        output wire                  fb_suff  ,
        output wire                  fb_full  ,
        input wire [DATA_WIDTH-1:0]  di       ,


        input  wire [2*B_PIXEL*N_KERNEL-1:0] acc_i,
        input  wire [2*B_PIXEL*N_KERNEL-1:0] acc_o,
        output wire                          acc_o_valid
 
    );

    localparam B_N_DSP_C = $clog2(N_CONV_UNIT << 2);
    localparam N_BUF_ENTRIES = 512;


    reg  [6:0] c2_cnt_r;

    wire [N_KERNEL-1:0] wb_we_i;


    // weight shape (c1: 12-bits, w: 2-bits, h: 2-bits, pad: 2-bits, stride: 2-bits).
    
    wire [1:0]           wcfg_stride ;
    wire [1:0]           wcfg_pad    ;
    wire [24:0]          wcfg_shape  ;
    wire [11:0]          wcfg_c1;

    // fm shape (c: 12-bits, w: 10-bits, h: 10-bits).
    wire [24:0] fcfg_shape  ;


    wire [N_FTMBUF_X*DATA_WIDTH-1:0] fb_do_raw;
    wire [DATA_WIDTH-1:0]            fb_do;
    wire [B_PIXEL-1:0]               fb_do_la [0:N_DSP_GROUP-1];

    wire [DATA_WIDTH-1:0]            wb_do_i [0:N_KERNEL-1];
    wire [B_PIXEL*N_KERNEL-1:0]      wb_do [0:N_DSP_GROUP-1];
    wire [B_PIXEL*N_KERNEL-1:0]      wb_do_la [0:N_DSP_GROUP-1];

    wire [2*B_PIXEL*N_KERNEL-1:0] acc_i_arr [0:N_DSP_GROUP-1];
    wire [2*B_PIXEL*N_KERNEL-1:0] acc_o_arr [0:N_DSP_GROUP-1];


    wire [B_COORD-1:0] c_i [0:1];
    wire [B_COORD-1:0] y_i [0:1];
    wire [B_COORD-1:0] x_i [0:1];

    wire [N_KERNEL:0] wb_tog;




    generate
        if (ID == wcfg_n_last_c1[1]) begin

            wire[7:0]                    n_wrap_c_lim;
            reg [7:0]                    n_wrap_c_r;
            reg [2*B_PIXEL*N_KERNEL-1:0] acc_r;
            reg [2*B_PIXEL*N_KERNEL-1:0] acc_o_r;
            reg                          acc_o_valid_r;

            always @( posedge clk ) begin

                if ( rstn == 1'b0 ) begin
                    n_wrap_c_r       <= 0;
                    acc_r            <= 0;
                    acc_o_r          <= 0;    
                    acc_o_valid_r    <= 0;    
                end 
                else begin    

                    if(pipe_en_o == 1'b1) begin

                        // Assume c1 is always == k * 4 * N_CONV_UNIT for k >= 1. Need to make it more general.
                        if(n_wrap_c_r == n_wrap_c_lim)begin
                        
                            n_wrap_c_r    <= 0;
                            acc_o_valid_r <= 1'b1;

                            for (i=0; i<N_KERNEL; i=i+1) begin

                                acc_r                           <= 0;
                                acc_o_r[i*2*B_PIXEL+:2*B_PIXEL] <=  acc_r[i*2*B_PIXEL+:2*B_PIXEL] +
                                                                acc_o_arr[N_DSP_GROUP-1][i*2*B_PIXEL+:2*B_PIXEL];
                            end
                        end                    
                        else begin
                            
                            n_wrap_c_r    <= n_wrap_c_r + 1;
                            acc_o_valid_r <= 1'b0;
                            
                            for (i=0; i<N_KERNEL; i=i+1) begin
                                acc_r[i*2*B_PIXEL+:2*B_PIXEL] <= acc_r[i*2*B_PIXEL+:2*B_PIXEL] + 
                                                                acc_o_arr[N_DSP_GROUP-1][i*2*B_PIXEL+:2*B_PIXEL];
                            end
                        end
                    end

                end
            end     

            // floor(c1 / (4*N_CONV_UNIT))
            assign n_wrap_c_lim = wcfg_n_wrap_c1[0]-1;

            assign acc_o       = acc_o_r;
            assign acc_o_valid = acc_o_valid_r; 

        end
        else begin
            assign acc_o       = acc_o_arr[N_DSP_GROUP-1];
            assign acc_o_valid = 1'b0;
        end
    endgenerate

    assign rd_en = (pipe_en == 1'b1) ? (ID == 0) ? 1'b1 : pipe_en_i
                                    : 1'b0;



    // #####################
    // # wr
    // #####################
    assign wcfg[0] = cfg_wr_data[0+:32];
    assign fcfg[0] = cfg_wr_data[32+:32];

    // wcfg: n_wrap_c2: 7-bits, n_wrap_c1: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits
    assign wcfg_stride      [0]        = wcfg[0][1:0]  ;
    assign wcfg_pad         [0]        = wcfg[0][3:2]  ;
    assign wcfg_shape       [0][0+:9]  = wcfg[0][5:4]  ; // w
    assign wcfg_shape       [0][9+:9]  = wcfg[0][7:6]  ; // h
    assign wcfg_shape       [0][18+:7] = wcfg[0][8+:7] ; // n_wrap_c1
    assign wcfg_n_wrap_c1   [0]        = wcfg[0][8+:7] ; // n_wrap_c1 == c1 / (4*N_CONV_UNIT).
    assign wcfg_n_wrap_c2   [0]        = wcfg[0][15+:7]; // n_wrap_c2 == c2 / N_KERNEL.
    assign wcfg_n_last_c1   [0]        = wcfg[0][22+:3];  
    

    // fcfg: n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits.
    assign fcfg_shape       [0][0+:9]  = fcfg[0][0+:9] ; // w
    assign fcfg_shape       [0][9+:9]  = fcfg[0][9+:9] ; // h
    assign fcfg_shape       [0][18+:7] = fcfg[0][25+:7]; // n_wrap_c (of each particular ftm).
    assign fcfg_n_wrap_c_sum[0]        = fcfg[0][18+:7]; // n_wrap_c_sum



    // #####################
    // # rd
    // #####################
    always @( posedge clk )
    begin
        if ( rstn == 1'b0 ) begin

        end 
        else begin    

            if (~cfg_rd_run)
                c2_cnt_r    <= 0;
            else
                if (fb_rd_last) 
                    c2_cnt_r <= c2_cnt_r + 1;
        end
    end    

    assign cfg_rd_done = (c2_cnt_r == wcfg_n_wrap_c2[1]);

    assign wcfg[1] = cfg_rd_data[0+:32];
    assign fcfg[1] = cfg_rd_data[32+:32];

    // wcfg: n_wrap_c2: 7-bits, n_wrap_c1: 7-bits, h: 2-bits, w: 2-bits, pad: 2-bits, stride: 2-bits
    assign wcfg_stride      [1]        = wcfg[1][1:0]  ;
    assign wcfg_pad         [1]        = wcfg[1][3:2]  ;
    assign wcfg_shape       [1][0+:9]  = wcfg[1][5:4]  ; // w
    assign wcfg_shape       [1][9+:9]  = wcfg[1][7:6]  ; // h
    assign wcfg_shape       [1][18+:7] = wcfg[1][8+:7] ; // n_wrap_c1
    assign wcfg_n_wrap_c1   [1]        = wcfg[1][8+:7] ; // n_wrap_c1 == c1 / (4*N_CONV_UNIT).
    assign wcfg_n_wrap_c2   [1]        = wcfg[1][15+:7]; // n_wrap_c2 == c2 / N_KERNEL.
    assign wcfg_n_last_c1   [1]        = wcfg[1][22+:3];  

    // fcfg: n_wrap_c: 7-bits, n_wrap_c_sum: 7-bits, h: 9-bits, w: 9-bits.
    assign fcfg_shape       [1][0+:9]  = fcfg[1][0+:9] ; // w
    assign fcfg_shape       [1][9+:9]  = fcfg[1][9+:9] ; // h
    assign fcfg_shape       [1][18+:7] = fcfg[1][25+:7]; // n_wrap_c (of each particular ftm).
    assign fcfg_n_wrap_c_sum[1]        = fcfg[1][18+:7]; // n_wrap_c_sum

    assign cfg_i_ready = wait_cfg_st;



    strided_buffer
        #(
            .N_BUF_X    (N_FTMBUF_X), 
            .B_BUF_ADDR (B_BUF_ADDR),
            .B_SHAPE   (B_SHAPE)  ,
            .DATA_WIDTH (DATA_WIDTH),
            .B_COORD    (B_COORD),
            .N_CONV_UNIT(N_CONV_UNIT),
            .UNIT_BURSTS(UNIT_BURSTS_WEI)
        )
        ftm_buffer
        (
            .clk  (clk	)	    ,    
            .rstn (rstn)        ,     

            // #####################
            // # wr
            // #####################
            .shape        (fcfg_shape       [0]),
            .n_wrap_c_sum (fcfg_n_wrap_c_sum[0]),

            .wr_en   (fb_we     ),
            .wr_di   (di        ),
            .wr_last (fb_wr_last),
            .wr_ptr  (fb_wptr   ), 
            .wr_base (          )        
            .wr_tog  (          ),

            // #####################
            // # rd
            // #####################
            .stride    (wcfg_stride[1])   ,
            .pad       (wcfg_pad   [1])   ,
            .ftm_shape (fcfg_shape [1]),
            .wei_shape (wcfg_shape [1]),
            
            .rd_en            (rd_en      ),
            .rd_do            (fb_do      ), 
            .rd_last          (fb_rd_last ),
            .rd_ptr           (fb_rptr    ), 
            .rd_base          (           )
            .rd_base_incr_en  (0          ),
        );

    assign fb_suff = (fb_rptr == fb_wptr) ? 1'b0: 1'b1 ;


    generate
    genvar i, ii;

        for (i=0; i < N_KERNEL; i=i+1) begin

            strided_buffer
                #(
                    .N_BUF_X    (N_WEIBUF_X), 
                    .B_BUF_ADDR (B_BUF_ADDR),
                    .B_SHAPE    (B_SHAPE)  ,
                    .DATA_WIDTH (DATA_WIDTH),
                    .B_COORD    (B_COORD),
                    .N_CONV_UNIT(N_CONV_UNIT),
                    .UNIT_BURSTS(UNIT_BURSTS_FTM)
                )
                wei_buffer
                (
                    .clk  (clk	)	    ,    
                    .rstn (rstn)         ,     

                    // #####################
                    // # wr
                    // #####################
                    .shape        (wcfg_shape    [0] ),
                    .n_wrap_c_sum (wcfg_n_wrap_c1[0] ),

                    .wr_en    (wb_we_i[i])  ,
                    .wr_di    (di)          ,
                    .wr_last  (wb_wr_last[i]),
                    .wr_ptr   ( ),     
                    .wr_base  (wb_wbase[i]) ,
                    .wr_tog   (wb_tog[i]  ),    

                    // #####################
                    // # rd
                    // #####################
                    .stride           (1            ) ,
                    .pad              (0            ) ,
                    .ftm_shape        (wcfg_shape[1]),        
                    .wei_shape        (wcfg_shape[1]),     

                    .rd_en            (rd_en),
                    .rd_do            (wb_do_i[i])  ,
                    .rd_last          (),
                    .rd_ptr           (),          
                    .rd_base          (wb_rbase[i])
                    .rd_base_incr_en  (fb_rd_last)
                );

            assign wb_we_i[i] = (i == 0) ? (wb_tog[0] == wb_tog[N_KERNEL-1]) ? wb_we : 1'b0:
                                           (wb_tog[i-1] ^ wb_tog[i])         ? wb_we : 1'b0;

            for (ii=0; ii < N_DSP_GROUP; ii=ii+1) 
                assign wb_do[ii][i*B_PIXEL+:B_PIXEL] = wb_do_i[i][ii*B_PIXEL+:B_PIXEL];
        end
    endgenerate 


    assign wb_full = (wb_wbase[0] > wb_rbase[0]) ? 
            (N_BUF_ENTRIES + wb_rbase[0] - wb_wbase[0] < UNIT_BURSTS) ? 1'b1: 1'b0 : // wraddr > rdaddr
            (                wb_rbase[0] - wb_wbase[0] < UNIT_BURSTS) ? 1'b1: 1'b0 ; // wraddr <= rdaddr

    assign wb_suff = (wb_wbase[N_KERNEL-1] < wb_rbase[N_KERNEL-1]) ? 
            (N_BUF_ENTRIES + 
            wb_wbase[N_KERNEL-1] - wb_rbase[N_KERNEL-1] >= wcfg_n_wrap_c1[1]*wcfg_w[1]*wcfg_h[1]) ? 1'b1: 1'b0 : 
           (wb_wbase[N_KERNEL-1] - wb_rbase[N_KERNEL-1] >= wcfg_n_wrap_c1[1]*wcfg_w[1]*wcfg_h[1]) ? 1'b1: 1'b0 ; 


    latency_reg
        #(
            .N(N_DSP_GROUP), 
            .B(1)
        )
        pipe_en_latency_reg_i
        (
            .clk	(clk			),
            .clk_en (pipe_en        ),
            .rstn	(rstn			),

            .din	(pipe_en_i      ),
            .dout	(pipe_en_o      )
        );

        

    generate
    genvar j;

        for (j=0; j < N_DSP_GROUP; j=j+1) begin : GEN_DSP_GROUP

            latency_reg
                #(
                    .N(j), // latency.
                    .B(B_PIXEL)
                )
                fb_latency_reg_i
                (
                    .clk	(clk			),
                    .clk_en (pipe_en        ),
                    .rstn	(rstn			),
            
                    .din	(fb_do[j*B_PIXEL+:B_PIXEL]	),
                    .dout	(fb_do_la[j]	)
                );

            latency_reg
                #(
                    .N(j), // latency.
                    .B(B_PIXEL*N_KERNEL)
                )
                wb_latency_reg_i
                (
                    .clk	(clk			),
                    .clk_en (pipe_en        ),
                    .rstn	(rstn			),
            
                    .din	(wb_do[j]	),
                    .dout	(wb_do_la[j]	)
                );


            dsp_group 
                #(
                    .N_KERNEL(N_KERNEL),
                    .B_PIXEL (B_PIXEL)
                )
                dsp_group_i
                (
                    .clk 	  (clk            ),
                    .clk_en   (pipe_en        ),
                    .rstn	  (rstn           ),

                    .skip     (skip           ),

                    .wei      (wb_do_la[j]    ),
                    .ftm      (fb_do_la[j]    ),

                    .acc_i    (acc_i_arr[j]),
                    .acc_o    (acc_o_arr[j])
                );

            assign acc_i_arr[j] = (j==0) ? acc_i: acc_o_arr[j-1];
        end
    endgenerate 

    assign skip = (ID >= wcfg_n_last_c1[1]) ? 1 : 0;

endmodule