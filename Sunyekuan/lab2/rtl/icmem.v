`timescale 1ns/1ps

module icmem (
    input  wire        clk,
    input  wire        rst,
    input  wire        execute,
    input  wire        inst_wen,
    input  wire [4:0]  inst_addr,
    input  wire [15:0] input_inst,
    output reg  [15:0] pc,
    output wire [15:0] current_inst
);
    always @(posedge clk or negedge rst) begin
        if (!rst)
            pc <= 16'd0;
        else if (execute)
            pc <= pc + 16'd1;
    end

    dcmem inst_mem1 (
        .clk(clk),
        .MemWEn(inst_wen),
        .addr(inst_wen ? inst_addr : pc[4:0]),
        .dataw(input_inst),
        .datar(current_inst)
    );
endmodule
