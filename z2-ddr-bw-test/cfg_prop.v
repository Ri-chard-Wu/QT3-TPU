

module cfg_prop
    #(
       
		parameter B = 128,  // need to be power of 2.
    
    )
    (
        input wire        clk ,    
        input wire        rstn, 

        // input
        input wire [B-1:0]  s_cfg_data ,
        input wire          s_cfg_valid,
        output wire         s_cfg_ready,

        input wire          incr_en,
        input wire [ ]      incr_lim


        // output
        output wire [B-1:0] m_cfg_data ,
        output wire         m_cfg_valid,
        input wire          m_cfg_ready,
    );


    always @( posedge clk )
    begin
        if ( rstn == 1'b0 ) begin

            state	<= WAIT_CFG_ST;
        end 
        else begin    

            case(state)
                WAIT_CFG_ST:
                    if (s_cfg_valid)
                        state <= RUN_ST;
                RUN_ST:
                    if(cnt_r == incr_lim)
                        if(slave_updated_r)
                            state <= WAIT_CFG_ST;
            endcase	

            if(wait_cfg_st && s_cfg_valid)
                slave_updated_r <= 0;
            else (run_st && m_cfg_ready)
                slave_updated_r <= 1;


            if (wait_cfg_st)
                cnt_r    <= 0;
            else if (run_st)
                if (incr_en) 
                    cnt_r <= cnt_r + 1;

            if (wait_cfg_st && s_cfg_valid) 
                cfg_data_r <= s_cfg_data;

        end
    end    

    always @(state) begin

        wait_cfg_st	  = 0;
        run_st         = 0;
    
        case (state)

            WAIT_CFG_ST:
                wait_cfg_st  = 1;

            RUN_ST:
                run_st       = 1;
        endcase
    end

    assign m_cfg_data = s_cfg_data;
    assign m_cfg_valid = m_cfg_ready & run_st;


endmodule