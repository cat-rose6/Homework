`timescale 1ns/1ps

module ai_core_top (
    input  wire        clk, rst_n,
    output wire [4:0]  pc,
    output wire        store_en,
    output wire [4:0]  store_addr,
    output wire [15:0] store_data
);
    wire [15:0] inst, imm;
    wire [3:0] rs1_addr, rs2_addr, rd_addr;
    wire [15:0] rs1_data, rs2_data, rd_data;
    wire [15:0] sum_addr, mem_data, mac_result;
    wire reg_wen, mem_wen, mac_en, mac_init, use_offset;
    wire [1:0] wb_sel;

    // 1. Fetch the instruction at the current PC, then decode it.
    icmem instr_mem (.clk(clk), .rst_n(rst_n), .pc(pc), .current_inst(inst));
    decoder decode (
        .inst(inst), .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .imm(imm), .reg_wen(reg_wen), .mem_wen(mem_wen), .mac_en(mac_en),
        .mac_init(mac_init), .use_offset(use_offset), .wb_sel(wb_sel)
    );

    // 2. Read operands, calculate the memory address or run the MAC.
    regfile rf (
        .clk(clk), .rst_n(rst_n), .wen(reg_wen),
        .rs1_addr(rs1_addr), .rs2_addr(rs2_addr), .rd_addr(rd_addr),
        .rd_data(rd_data), .rs1_data(rs1_data), .rs2_data(rs2_data)
    );
    assign sum_addr = rs1_data + imm;
    assign store_addr = use_offset ? sum_addr[4:0] : rs1_data[4:0];
    assign store_en = rst_n && mem_wen;
    assign store_data = rs2_data;
    dcmem data_mem (
        .clk(clk), .wen(store_en), .addr(store_addr),
        .dataw(store_data), .datar(mem_data)
    );
    mac_alu mac (
        .clk(clk), .rst_n(rst_n), .en(mac_en), .init(mac_init),
        .rs1(rs1_data), .rs2(rs2_data), .result(mac_result)
    );

    // 3. Select what goes back to rd. Storage elements update on the rising edge.
    assign rd_data = (wb_sel == 2'b00) ? mem_data :
                     (wb_sel == 2'b01) ? imm : mac_result;
endmodule
