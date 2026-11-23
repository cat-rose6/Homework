`timescale 1ns/1ps

module dcmem #(
    parameter MEM_ADDR_WIDTH = 5,
    parameter MEM_DATA_WIDTH = 16,
    parameter MEM_NUMBER = 32
) (
    input  wire                      clk,
    input  wire                      MemWEn,
    input  wire [MEM_ADDR_WIDTH-1:0] addr,
    input  wire [MEM_DATA_WIDTH-1:0] dataw,
    output wire [MEM_DATA_WIDTH-1:0] datar
);
    reg [MEM_DATA_WIDTH-1:0] RAM [MEM_NUMBER-1:0];

    always @(posedge clk) begin
        if (MemWEn)
            RAM[addr] <= dataw;
    end

    assign datar = RAM[addr];
endmodule
