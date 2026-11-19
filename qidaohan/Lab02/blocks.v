`timescale 1ns/1ps

// Register file and memory organization adapted from lecture 7, pp. 17-19.
module regfile (
    input  wire        clk, rst_n, wen,
    input  wire [3:0]  rs1_addr, rs2_addr, rd_addr,
    input  wire [15:0] rd_data,
    output wire [15:0] rs1_data, rs2_data
);
    reg [15:0] regs [0:15];
    integer i;

    assign rs1_data = (rs1_addr == 0) ? 16'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 16'd0 : regs[rs2_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1)
                regs[i] <= 16'd0;
        end else if (wen && rd_addr != 0) begin
            regs[rd_addr] <= rd_data;
        end
    end
endmodule

module icmem (
    input  wire        clk, rst_n,
    output reg  [4:0]  pc,
    output wire [15:0] current_inst
);
    // The testbench loads the program into these 32 instruction words.
    reg [15:0] program_mem [0:31];
    assign current_inst = program_mem[pc];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 5'd0;
        else
            pc <= pc + 5'd1;
    end
endmodule

module dcmem (
    input  wire        clk, wen,
    input  wire [4:0]  addr,
    input  wire [15:0] dataw,
    output wire [15:0] datar
);
    reg [15:0] data_mem [0:31];
    assign datar = data_mem[addr];

    always @(posedge clk) begin
        if (wen)
            data_mem[addr] <= dataw;
    end
endmodule

module mac_alu (
    input  wire        clk, rst_n, en, init,
    input  wire [15:0] rs1, rs2,
    output wire [15:0] result
);
    reg  [15:0] psum;
    wire [15:0] product;

    // Keep the low 16 bits, as in the lecture's 16-bit datapath.
    assign product = $signed(rs1) * $signed(rs2);
    assign result = init ? rs1 : (psum + product);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            psum <= 16'd0;
        else if (en)
            psum <= result;  // init=1 loads the bias. Other opcodes leave it alone.
    end
endmodule
