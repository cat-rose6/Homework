`timescale 1ns/1ps

module MAC_ALU #(
    parameter REG_DATA_WIDTH = 16
) (
    input  wire                      clk,
    input  wire                      rst,
    input  wire                      mac_en,
    input  wire                      funct,
    input  wire [REG_DATA_WIDTH-1:0] rs1,
    input  wire [REG_DATA_WIDTH-1:0] rs2,
    output wire [REG_DATA_WIDTH-1:0] rd
);
    reg  [REG_DATA_WIDTH-1:0] psum;
    wire [REG_DATA_WIDTH-1:0] product;

    assign product = $signed(rs1) * $signed(rs2);
    assign rd = funct ? rs1 : psum + product;

    always @(posedge clk or negedge rst) begin
        if (!rst)
            psum <= 0;
        else if (mac_en)
            psum <= rd;
    end
endmodule
