`timescale 1ns/1ps

module regfile #(
    parameter REG_ADDR_WIDTH = 4,
    parameter REG_DATA_WIDTH = 16,
    parameter REG_NUMBER = 16
) (
    input  wire [REG_ADDR_WIDTH-1:0] rs1_addr,
    input  wire [REG_ADDR_WIDTH-1:0] rs2_addr,
    input  wire [REG_ADDR_WIDTH-1:0] rd_addr,
    input  wire [REG_DATA_WIDTH-1:0] rd_data,
    input  wire                      RegWEn,
    input  wire                      clk,
    input  wire                      rst,
    output wire [REG_DATA_WIDTH-1:0] rs1_data,
    output wire [REG_DATA_WIDTH-1:0] rs2_data
);
    reg [REG_DATA_WIDTH-1:0] rf [REG_NUMBER-1:0];
    integer index;

    assign rs1_data = (rs1_addr == 0) ? {REG_DATA_WIDTH{1'b0}} : rf[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? {REG_DATA_WIDTH{1'b0}} : rf[rs2_addr];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (index = 0; index < REG_NUMBER; index = index + 1)
                rf[index] <= 0;
        end else if (RegWEn && rd_addr != 0) begin
            rf[rd_addr] <= rd_data;
        end
    end
endmodule
