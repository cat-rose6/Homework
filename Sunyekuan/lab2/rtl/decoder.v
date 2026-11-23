`timescale 1ns/1ps

module decoder (
    input  wire [15:0] inst,
    output wire [3:0]  rd_addr,
    output wire [3:0]  rs1_addr,
    output wire [3:0]  rs2_addr,
    output wire [4:0]  imm5,
    output wire [15:0] imm9,
    output wire        funct,
    output reg         reg_wen,
    output reg         mem_wen,
    output reg         mac_en,
    output reg         addr_add_imm,
    output reg  [1:0]  wb_sel
);
    localparam [2:0] OP_LOAD  = 3'b001,
                     OP_STORE = 3'b010,
                     OP_MOV   = 3'b011,
                     OP_MAC   = 3'b100;

    localparam [1:0] WB_MEM  = 2'b00,
                     WB_MAC  = 2'b01,
                     WB_IMM  = 2'b10,
                     WB_NONE = 2'b11;

    assign rd_addr  = inst[12:9];
    assign rs1_addr = inst[8:5];
    assign rs2_addr = inst[4:1];
    assign imm5     = inst[4:0];
    assign imm9     = {7'b0, inst[8:0]};
    assign funct    = inst[0];

    always @* begin
        reg_wen      = 1'b0;
        mem_wen      = 1'b0;
        mac_en       = 1'b0;
        addr_add_imm = 1'b0;
        wb_sel       = WB_NONE;

        case (inst[15:13])
            OP_LOAD: begin
                reg_wen      = 1'b1;
                addr_add_imm = 1'b1;
                wb_sel       = WB_MEM;
            end
            OP_STORE: mem_wen = 1'b1;
            OP_MOV: begin
                reg_wen = 1'b1;
                wb_sel  = WB_IMM;
            end
            OP_MAC: begin
                reg_wen = 1'b1;
                mac_en  = 1'b1;
                wb_sel  = WB_MAC;
            end
            default: begin end
        endcase
    end
endmodule
