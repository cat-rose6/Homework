
`timescale 1ns/1ps
module tinyai16_cpu (
    input wire clk,
    input wire reset_n,
    output reg halted,
    output wire [7:0] pc_out
);
reg [15:0] regs [0:15];
reg [15:0] imem [0:255];
reg [15:0] dmem [0:63];
reg [7:0] pc;

wire [15:0] inst = imem[pc];
wire [2:0] opcode = inst[15:13];
wire [3:0] rd = inst[12:9];
wire [3:0] rs1 = inst[8:5];
wire [3:0] rs2 = inst[4:1];

wire [15:0] imm9 = {{7{inst[8]}},inst[8:0]};
wire [15:0] imm5 = {{11{inst[4]}},inst[4:0]};
wire [15:0] full_addr = regs[rs1] + imm5;
wire [5:0] addr = full_addr[5:0];

wire signed [31:0] product =
    $signed(regs[rs1]) * $signed(regs[rs2]);

assign pc_out = pc;

initial begin
    $readmemh("program.hex", imem);
    $readmemh("data.hex", dmem);
end

integer i;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        pc <= 0;
        halted <= 0;
        for(i=0;i<16;i=i+1)
            regs[i] <= 0;
    end else if(!halted) begin
        pc <= pc + 8'd1;
        case(opcode)
            3'd0: if(rd!=0)
                regs[rd] <= imm9;                // MOVI
            3'd1: if(rd!=0)
                regs[rd] <= dmem[addr];          // LOAD
            3'd2:
                dmem[addr] <= regs[rd];          // STORE
            3'd3: if(rd!=0)
                regs[rd] <= regs[rs1]+regs[rs2];// ADD
            3'd4: if(rd!=0)
                regs[rd] <= regs[rs1]-regs[rs2];// SUB
            3'd5: if(rd!=0)
                regs[rd] <= regs[rd]+product[15:0]; // MAC
            3'd6: if(regs[rd]!=0)
                pc <= pc+8'd1+imm9[7:0];        // BNZ
            3'd7: begin
                halted <= 1;                    // HALT
                pc <= pc;
            end
        endcase
    end
end
endmodule
