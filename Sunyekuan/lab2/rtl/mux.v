`timescale 1ns/1ps

module MUX #(
    parameter DATA_WIDTH = 16
) (
    input  wire [1:0]            S,
    input  wire [DATA_WIDTH-1:0] A,
    input  wire [DATA_WIDTH-1:0] B,
    input  wire [DATA_WIDTH-1:0] C,
    input  wire [DATA_WIDTH-1:0] D,
    output reg  [DATA_WIDTH-1:0] Y
);
    always @* begin
        case (S)
            2'b00: Y = A;
            2'b01: Y = B;
            2'b10: Y = C;
            default: Y = D;
        endcase
    end
endmodule
