`timescale 1ns/1ps

module ai_core_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        run,
    input  wire        inst_wen,
    input  wire [4:0]  inst_addr,
    input  wire [15:0] input_inst,
    input  wire        data_wen,
    input  wire [4:0]  data_addr,
    input  wire [15:0] data_in,
    output wire [15:0] data_out,
    output wire [15:0] pc,
    output wire [15:0] current_inst
);
    wire        execute;
    wire [3:0]  rd_addr, rs1_addr, rs2_addr;
    wire [4:0]  imm5, core_mem_addr;
    wire [15:0] imm9, rs1_data, rs2_data, rd_data, mac_result;
    wire        funct, reg_wen, mem_wen, mac_en, addr_add_imm;
    wire [1:0]  wb_sel;

    assign execute = rst && run && !inst_wen && !data_wen;
    assign core_mem_addr = addr_add_imm ? rs1_data[4:0] + imm5 : rs1_data[4:0];

    icmem instructions (
        .clk(clk), .rst(rst), .execute(execute),
        .inst_wen(inst_wen), .inst_addr(inst_addr), .input_inst(input_inst),
        .pc(pc), .current_inst(current_inst)
    );

    decoder decode (
        .inst(current_inst), .rd_addr(rd_addr), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .imm5(imm5), .imm9(imm9), .funct(funct),
        .reg_wen(reg_wen), .mem_wen(mem_wen), .mac_en(mac_en),
        .addr_add_imm(addr_add_imm), .wb_sel(wb_sel)
    );

    regfile registers (
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr),
        .rd_addr(rd_addr), .rd_data(rd_data), .RegWEn(execute && reg_wen),
        .clk(clk), .rst(rst), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );

    dcmem data_memory (
        .clk(clk), .MemWEn(data_wen || (execute && mem_wen)),
        .addr(execute ? core_mem_addr : data_addr),
        .dataw(execute ? rs2_data : data_in), .datar(data_out)
    );

    MAC_ALU mac (
        .clk(clk), .rst(rst), .mac_en(execute && mac_en),
        .funct(funct), .rs1(rs1_data), .rs2(rs2_data), .rd(mac_result)
    );

    MUX writeback (
        .S(wb_sel), .A(data_out), .B(mac_result),
        .C(imm9), .D(16'd0), .Y(rd_data)
    );
endmodule
