`timescale 1ns/1ps

module tb_ai_core_top;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg run = 1'b0;
    reg inst_wen = 1'b0;
    reg [4:0] inst_addr = 5'd0;
    reg [15:0] input_inst = 16'd0;
    reg data_wen = 1'b0;
    reg [4:0] data_addr = 5'd0;
    reg [15:0] data_in = 16'd0;
    wire [15:0] data_out, pc, current_inst;
    reg [15:0] neuron_program [0:12];
    integer instruction_index;

    ai_core_top dut (
        .clk(clk), .rst(rst), .run(run),
        .inst_wen(inst_wen), .inst_addr(inst_addr), .input_inst(input_inst),
        .data_wen(data_wen), .data_addr(data_addr), .data_in(data_in),
        .data_out(data_out), .pc(pc), .current_inst(current_inst)
    );

    always #5 clk = ~clk;

    task check_word(input [8*48-1:0] label_text, input [15:0] actual, expected);
        if (actual !== expected) begin
            $display("FAIL: %s: got %h, expected %h", label_text, actual, expected);
            $finish;
        end
    endtask

    task load_instruction(input [4:0] address, input [15:0] word);
        begin
            @(negedge clk);
            inst_wen = 1'b1;
            inst_addr = address;
            input_inst = word;
            @(negedge clk);
            inst_wen = 1'b0;
        end
    endtask

    task load_data(input [4:0] address, input [15:0] word);
        begin
            @(negedge clk);
            data_wen = 1'b1;
            data_addr = address;
            data_in = word;
            @(negedge clk);
            data_wen = 1'b0;
        end
    endtask

    task step(input integer cycles);
        begin
            repeat (cycles) @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $readmemh("program/neuron16.hex", neuron_program);
        #1 rst = 1'b0;
        repeat (2) @(negedge clk);
        rst = 1'b1;

        for (instruction_index = 0; instruction_index < 13; instruction_index = instruction_index + 1)
            load_instruction(instruction_index[4:0], neuron_program[instruction_index]);
        load_instruction(5'd13, 16'h6dff);
        load_instruction(5'd14, 16'h607b);
        load_instruction(5'd15, 16'h2e1f);
        load_instruction(5'd16, 16'hffff);
        load_instruction(5'd17, 16'h90e9);
        load_instruction(5'd18, 16'h9088);
        load_instruction(5'd19, 16'h4010);
        load_instruction(5'd20, 16'h323f);
        load_instruction(5'd21, 16'h0000);
        load_instruction(5'd22, 16'h0000);

        load_data(5'd4, 16'd7);
        load_data(5'd8, 16'd3);
        load_data(5'd9, -16'sd2);
        load_data(5'd12, 16'd4);
        load_data(5'd13, 16'd5);
        load_data(5'd15, 16'h1234);
        load_data(5'd16, 16'hdead);
        load_data(5'd31, -16'sd30);
        check_word("PC while loading", pc, 16'd0);

        @(negedge clk);
        run = 1'b1;
        step(3);
        check_word("MAC init writeback", dut.registers.rf[5], 16'd7);
        check_word("MAC init accumulator", dut.mac.psum, 16'd7);
        $display("PC=2: bias loaded into R5 and psum: %0d", dut.mac.psum);
        step(5);
        check_word("First product plus bias", dut.registers.rf[5], 16'd19);
        $display("PC=7: first product plus bias: %0d", dut.registers.rf[5]);
        step(3);
        check_word("Signed second product", dut.registers.rf[5], 16'd9);
        $display("PC=10: second product added: %0d", dut.registers.rf[5]);
        step(1);
        check_word("PC after 12 enabled cycles", pc, 16'd12);
        check_word("STORE fetched from instruction memory", current_inst, 16'h402a);

        @(negedge clk);
        run = 1'b0;
        data_addr = 5'd16;
        step(1);
        check_word("PC while paused at STORE", pc, 16'd12);
        check_word("STORE does not write while paused", data_out, 16'hdead);
        @(negedge clk);
        run = 1'b1;
        step(1);
        check_word("Neuron output STORE", dut.data_memory.RAM[16], 16'd9);
        $display("PC=12: mem[16] = %0d", dut.data_memory.RAM[16]);

        step(1);
        check_word("9-bit MOV", dut.registers.rf[6], 16'd511);
        step(1);
        check_word("R0 rejects writes", dut.registers.rf[0], 16'd0);
        step(1);
        check_word("31-word LOAD offset", dut.registers.rf[7], -16'sd30);
        step(1);
        check_word("Reserved opcode keeps rd", dut.registers.rf[15], 16'd0);
        check_word("Reserved opcode keeps psum", dut.mac.psum, 16'd9);
        step(1);
        check_word("MAC init selects rs1 instead of rs2", dut.registers.rf[8], -16'sd30);
        check_word("MAC init replaces nonzero psum", dut.mac.psum, -16'sd30);
        step(1);
        check_word("MAC after reinitializing", dut.registers.rf[8], -16'sd5);
        step(2);
        check_word("Five-bit data address wraps", dut.registers.rf[9], 16'h1234);
        step(1);
        check_word("Opcode 0 keeps psum", dut.mac.psum, -16'sd5);
        check_word("PC at end of program", pc, 16'd22);

        @(negedge clk);
        run = 1'b0;
        data_addr = 5'd0;
        #1 check_word("Read back second STORE", data_out, -16'sd5);
        data_addr = 5'd16;
        #1 check_word("Read back neuron output", data_out, 16'd9);
        rst = 1'b0;
        #1;
        check_word("Reset clears PC", pc, 16'd0);
        check_word("Reset clears accumulator", dut.mac.psum, 16'd0);
        check_word("Reset clears registers", dut.registers.rf[5], 16'd0);
        check_word("Reset preserves data memory", data_out, 16'd9);
        $display("PASS: neuron program and core checks");
        $finish;
    end
endmodule
