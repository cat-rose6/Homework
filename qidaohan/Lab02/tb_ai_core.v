`timescale 1ns/1ps

module tb_ai_core;
    localparam [4:0] ADX = 5'd8, ADW = 5'd10, ADB = 5'd12, ADY = 5'd13;

    reg clk = 0;
    reg rst_n = 0;
    wire [4:0] pc, store_addr;
    wire store_en;
    wire [15:0] store_data;
    integer i;

    ai_core_top dut (
        .clk(clk), .rst_n(rst_n), .pc(pc),
        .store_en(store_en), .store_addr(store_addr), .store_data(store_data)
    );
    always #5 clk = ~clk;

    // These functions pack each assembly instruction into a 16-bit word.
    function [15:0] mov_word(input [3:0] rd, input [8:0] imm);
        mov_word = {3'b011, rd, imm};
    endfunction

    function [15:0] load_word(input [3:0] rd, input [3:0] base, input [4:0] offset);
        load_word = {3'b001, rd, base, offset};
    endfunction

    function [15:0] mac_word(input [3:0] rd, input [3:0] rs1, rs2, input funct);
        mac_word = {3'b100, rd, rs1, rs2, funct};
    endfunction

    function [15:0] store_word(input [3:0] addr_reg, data_reg);
        store_word = {3'b010, 4'b0000, addr_reg, data_reg, 1'b0};
    endfunction

    task check_r5(input [15:0] expected);
        begin
            #1;  // Wait for the register write on this edge to take effect.
            if (dut.rf.regs[5] !== expected)
                $fatal(1, "R5 was %0d, expected %0d", dut.rf.regs[5], expected);
            $display("MAC writeback: R5 = %0d", dut.rf.regs[5]);
        end
    endtask

    initial begin
        for (i = 0; i < 32; i = i + 1)
            dut.instr_mem.program_mem[i] = 16'h0000;

        dut.data_mem.data_mem[ADX]     = 16'd2;  // x1
        dut.data_mem.data_mem[ADX+1]   = 16'd3;  // x2
        dut.data_mem.data_mem[ADW]     = 16'd4;  // w1
        dut.data_mem.data_mem[ADW+1]   = 16'd5;  // w2
        dut.data_mem.data_mem[ADB]     = 16'd1;  // b
        dut.data_mem.data_mem[ADY]     = 16'd0;

        // Lecture 7, p. 16: R5 starts at b and accumulates both products.
        dut.instr_mem.program_mem[0]  = mov_word(1, {4'b0, ADB});
        dut.instr_mem.program_mem[1]  = load_word(2, 1, 0);
        dut.instr_mem.program_mem[2]  = mac_word(5, 2, 0, 1);
        dut.instr_mem.program_mem[3]  = mov_word(1, {4'b0, ADX});
        dut.instr_mem.program_mem[4]  = mov_word(2, {4'b0, ADW});
        dut.instr_mem.program_mem[5]  = load_word(3, 1, 0);
        dut.instr_mem.program_mem[6]  = load_word(4, 2, 0);
        dut.instr_mem.program_mem[7]  = mac_word(5, 3, 4, 0);
        dut.instr_mem.program_mem[8]  = load_word(3, 1, 1);
        dut.instr_mem.program_mem[9]  = load_word(4, 2, 1);
        dut.instr_mem.program_mem[10] = mac_word(5, 3, 4, 0);
        dut.instr_mem.program_mem[11] = mov_word(1, {4'b0, ADY});
        dut.instr_mem.program_mem[12] = store_word(1, 5);

        repeat (2) @(negedge clk);
        rst_n = 1;

        for (i = 0; i < 13; i = i + 1) begin
            @(posedge clk);
            if (pc !== i[4:0])
                $fatal(1, "PC was %0d, expected %0d", pc, i);
            if (i < 12 && store_en !== 1'b0)
                $fatal(1, "Unexpected memory write at PC %0d", pc);
            case (i)
                2:  check_r5(16'd1);
                7:  check_r5(16'd9);
                10: check_r5(16'd24);
                12: if (store_en !== 1'b1 || store_addr !== ADY || store_data !== 16'd24)
                        $fatal(1, "STORE did not send 24 to address %0d", ADY);
                default: begin end
            endcase
        end

        #1;
        if (dut.data_mem.data_mem[ADY] !== 16'd24)
            $fatal(1, "Final memory value was not 24");
        $display("PASS: mem[%0d] = %0d (expected 24)", ADY, dut.data_mem.data_mem[ADY]);
        $finish;
    end
endmodule
