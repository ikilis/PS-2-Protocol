




module ps2(input clk,
           input rst_n,
           input kb_data,
           input kb_clk,
           output [15:0] buffer_out,
           output error);
    
    
    // STATEs
    localparam IDLE      = 2'b00;     // expecting start bit
    localparam RECEIVING = 2'b01;     // receiving data
    localparam CHECK     = 2'b10;     // receiving & checking parity bit
    localparam STOP      = 2'b11;     // expecting stop bit
    
    
    
    reg [15:0] received_data_reg, received_data_next;
    reg parity_reg, parity_next;
    reg [3:0] cnt_reg, cnt_next;
    reg error_reg, error_next;
    reg [1:0] state_reg, state_next;
    
    assign buffer_out = received_data_reg;
    assign error      = error_reg;
    
    
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            // reset _reg = initial value
            received_data_reg <= 16'h0000;
            cnt_reg           <= 4'h0;
            error_reg         <= 1'b0;
            parity_reg        <= 1'b0;
            state_reg         <= IDLE;
            end else begin
            // _reg = _next
            received_data_reg <= received_data_next;
            parity_reg        <= parity_next;
            cnt_reg           <= cnt_next;
            error_reg         <= error_next;
            state_reg         <= state_next;
        end
    end
    
    always @(negedge kb_clk) begin
        // *_next = _reg
        received_data_next = received_data_reg;
        state_next         = state_reg;
        cnt_next           = cnt_reg;
        error_next         = error_reg;
        parity_next        = parity_reg;
        
        // state machine
        case(state_reg)
            IDLE: begin
                if (kb_data == 1'b0) begin
                    error_next = 1'b0;
                    state_next = RECEIVING;
                end
            end
            
            RECEIVING: begin
                if (cnt_reg % 8 == 0) begin
                    parity_next = kb_data;
                    end else begin
                        parity_next = parity_reg ^ kb_data;
                    end
                    received_data_next[cnt_reg] = kb_data;
                    cnt_next                    = cnt_reg + 1'b1;
                    
                    if (cnt_next % 8 == 0) begin
                        state_next = CHECK;
                    end
                end
                
                CHECK: begin
                    if (parity_reg ^ kb_data == 1'b0) begin
                        error_next = 1'b1;
                        end else begin
                            error_next = 1'b0;
                        end
                        state_next = STOP;
                    end
                    
                    STOP: begin
                        if (kb_data == 1'b1) begin
                            state_next = IDLE;
                            end else begin
                                error_next = 1'b1;
                                state_next = IDLE;
                            end
                        end
        endcase
        
    end
    
endmodule
    
    
