

module cfg_prop
    #(
       
		parameter B = 64, 
    )
    (
        input wire        clk ,    
        input wire        rstn, 

        input wire [B-1:0]  s_cfg_data ,
        input wire          s_cfg_valid,
        output wire         s_cfg_ready,

        input wire          m_cfg_done,
        output wire         m_cfg_run,
        output wire [B-1:0] m_cfg_data ,
        output wire         m_cfg_valid,
        input wire          m_cfg_ready,
    );


    localparam WAIT_MST_CFG_ST  = 0;
    localparam RUN_ST           = 1;
    // localparam WAIT_SLV_CFG_ST  = 2;
    

    reg  [2:0] state    ;
    reg  wait_mst_cfg_st;
    reg  run_st         ;

    reg         slave_updated_r;
    reg  [63:0] cfg_data_r     ;


    always @( posedge clk )
    begin
        if ( rstn == 1'b0 ) begin

            state	        <= WAIT_MST_CFG_ST;
            slave_updated_r <= 0;
            cfg_data_r      <= 0;
        end 
        else begin    

            case(state)

                WAIT_MST_CFG_ST:
                    if (s_cfg_valid)
                        state <= RUN_ST;

                RUN_ST:
                    if(m_cfg_done)
                        if(slave_updated_r)
                            state <= WAIT_MST_CFG_ST;
         
            endcase	
 
            if(wait_mst_cfg_st)
                slave_updated_r <= 0;
            else (m_cfg_ready & m_cfg_valid)
                slave_updated_r <= 1;

            if (wait_mst_cfg_st) 
                cfg_data_r <= s_cfg_data;

        end
    end    

    always @(state) begin

        wait_mst_cfg_st	  = 0;
        run_st            = 0;
    
        case (state)

            WAIT_MST_CFG_ST:
                wait_mst_cfg_st  = 1;

            RUN_ST:
                run_st           = 1;
        endcase
    end

    assign m_cfg_run   = run_st;

    assign m_cfg_data  = cfg_data_r;
    assign m_cfg_valid = ~wait_mst_cfg_st;


endmodule