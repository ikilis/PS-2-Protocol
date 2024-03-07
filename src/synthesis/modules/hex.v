module hex(input [15:0] input_data,
           input error,
           output reg [6:0] display0,
           output reg [6:0] display1,
           output reg [6:0] display2,
           output reg [6:0] display3);


localparam NONE     = ~7'h00;
localparam LETTER_E = ~7'h79;
localparam LETTER_R = ~7'h50;

// verilog function
function [6:0] hex_to_code; //out
    input [3:0] hex_number; //in
    
    begin
        case (hex_number)
            4'b0000: hex_to_code = ~7'h3F;
            4'b0001: hex_to_code = ~7'h06;
            4'b0010: hex_to_code = ~7'h5B;
            4'b0011: hex_to_code = ~7'h4F;
            4'b0100: hex_to_code = ~7'h66;
            4'b0101: hex_to_code = ~7'h6D;
            4'b0110: hex_to_code = ~7'h7D;
            4'b0111: hex_to_code = ~7'h07;
            4'b1000: hex_to_code = ~7'h7F;
            4'b1001: hex_to_code = ~7'h6F;
            4'b1010: hex_to_code = ~7'h77;
            4'b1011: hex_to_code = ~7'h7C;
            4'b1100: hex_to_code = ~7'h39;
            4'b1101: hex_to_code = ~7'h5E;
            4'b1110: hex_to_code = ~7'h79;
            4'b1111: hex_to_code = ~7'h71;
        endcase
    end
    
endfunction


// code
always @(*) begin
    if (error == 1'b1) begin
        display3 = NONE;
        display2 = LETTER_E;
        display1 = LETTER_R;
        display0 = LETTER_R;
        end else begin
        
        display0 = hex_to_code(input_data[3:0]);
        display1 = hex_to_code(input_data[7:4]);
        display2 = hex_to_code(input_data[11:8]);
        display3 = hex_to_code(input_data[15:12]);
    end
end


endmodule
