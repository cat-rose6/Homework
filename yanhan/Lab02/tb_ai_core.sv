`timescale 1ns/1ps
module tb_ai_core;
    import simple_isa::*;
    reg clk = 0, rst = 1, inst_wen = 0;
    reg [15:0] input_inst = 0;
    wire data_wen;
    wire [4:0] data_addr;
    wire [15:0] data_wdata;
    ai_core_top dut (.*);
    always #5 clk = ~clk;

    function automatic [15:0] mov(input [3:0] rd, input [8:0] imm);
        return {OP_MOV, rd, imm};
    endfunction
    function automatic [15:0] load_word(input [3:0] rd, base, input [4:0] offset);
        return {OP_LOAD, rd, base, offset};
    endfunction
    function automatic [15:0] store_word(input [3:0] base, src);
        return {OP_STORE, 4'd0, base, src, 1'b0};
    endfunction
    function automatic [15:0] mac(input [3:0] rd, rs1, rs2, input bit funct);
        return {OP_MAC, rd, rs1, rs2, funct};
    endfunction

    localparam [4:0] ADX = 31, ADW = 8, ADB = 12, ADY = 13;
    reg [15:0] code [0:31];
    integer used;
    task automatic emit(input [15:0] word);
        if (used >= 32) $fatal(1, "Program exceeds instruction memory");
        code[used] = word;
        used++;
    endtask
    task automatic init_data(input [4:0] addr, input integer value);
        emit(mov(1, addr));
        emit(mov(2, value));
        emit(store_word(1, 2));
    endtask

    task automatic run_neuron(input integer x1, x2, w1, w2, bias);
        reg [15:0] expected;
        integer i;
        used = 0;
        expected = x1*w1 + x2*w2 + bias;
        // 用处理器指令准备输入；第二个 x 放在字地址 0，覆盖基址加偏移回绕。
        init_data(ADX, x1);
        init_data(ADX + 5'd1, x2);
        init_data(ADW, w1);
        init_data(ADW + 5'd1, w2);
        init_data(ADB, bias);

        // R5 先保存偏置，再依次累加两个输入与各自权重的乘积。
        emit(mov(1, ADB));
        emit(load_word(2, 1, 0));
        emit(mac(5, 2, 0, 1));
        emit(mov(1, ADX));
        emit(mov(2, ADW));
        emit(load_word(3, 1, 0));
        emit(load_word(4, 2, 0));
        emit(mac(5, 3, 4, 0));
        emit(load_word(3, 1, 1));
        emit(load_word(4, 2, 1));
        emit(mac(5, 3, 4, 0));
        emit(mov(1, ADY));
        emit(store_word(1, 5));

        emit(mov(0, 123));                      // R0 恒为零
        emit({3'b111, 4'd1, 4'd1, 4'd0, 1'b1}); // 保留编码不产生写入
        emit(load_word(6, 1, 0));               // 从 ADY 读回实际写入值
        emit(store_word(0, 6));

        @(negedge clk);
        rst = 0;
        inst_wen = 1;
        @(negedge clk);
        rst = 1;
        for (i = 0; i < used; i++) begin
            input_inst = code[i];
            @(posedge clk);
            if (data_wen !== 1'b0) $fatal(1, "STORE during programming");
            @(negedge clk);
        end
        rst = 0;
        inst_wen = 0;
        @(negedge clk);
        rst = 1;
        for (i = 0; i < used; i++) begin
            @(posedge clk);
            if (data_wen !== (code[i][15:13] == OP_STORE))
                $fatal(1, "Wrong memory write enable at PC=%0d", i);
            if (i == used-5 || i == used-1) begin
                if (data_addr !== ((i == used-5) ? ADY : 5'd0) ||
                    data_wdata !== expected)
                    $fatal(1, "PC=%0d addr=%0d data=%h expected=%h",
                           i, data_addr, data_wdata, expected);
            end
        end
        $display("PASS x=(%0d,%0d) w=(%0d,%0d) b=%0d -> y=%0d (0x%04h)",
                 x1, x2, w1, w2, bias, $signed(expected), expected);
    endtask

    initial begin
        run_neuron(3, 4, 5, 6, 7);
        run_neuron(-3, 4, 5, -6, -7);
        run_neuron(0, 0, 0, 0, -256);
        run_neuron(255, 255, 255, 255, 255);
        $finish;
    end
endmodule
