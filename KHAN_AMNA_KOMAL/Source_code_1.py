import os
import subprocess
import matplotlib.pyplot as plt
import numpy as np

# 1. Install Icarus Verilog compiler in the Colab Linux environment
print("1/4: Installing Icarus Verilog compiler...")
subprocess.run("apt-get update -qq && apt-get install -y -qq iverilog", shell=True, check=True)

# 2. Write the complete Verilog hardware design + testbench into a single file
print("2/4: Generating ai_processor.v (Slides 14-25 implementation)...")
verilog_code = r"""`timescale 1ns / 1ps

// ============================================================================
// STEP 1: Register File Module (Slide 17)
// ============================================================================
module regfile #(
    parameter REG_ADDR_WIDTH = 4,
    parameter REG_DATA_WIDTH = 16,
    parameter REG_NUMBER     = 16
)(
    input  [REG_ADDR_WIDTH-1:0] rs1_addr,
    input  [REG_ADDR_WIDTH-1:0] rs2_addr,
    input  [REG_ADDR_WIDTH-1:0] rd_addr,
    input  [REG_DATA_WIDTH-1:0] rd_data,
    input                       RegWEn,
    input                       clk,
    input                       rst,
    output [REG_DATA_WIDTH-1:0] rs1_data,
    output [REG_DATA_WIDTH-1:0] rs2_data
);
    reg [REG_DATA_WIDTH-1:0] rf [REG_NUMBER-1:0];
    integer i;

    assign rs1_data = (rs1_addr == 0) ? 16'd0 : rf[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 16'd0 : rf[rs2_addr];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < REG_NUMBER; i = i + 1) begin
                rf[i] <= 16'd0;
            end
        end else if (RegWEn && (rd_addr != 0)) begin
            rf[rd_addr] <= rd_data;
        end
    end
endmodule

// ============================================================================
// STEP 2: Data and Instruction Memory Modules (Slide 18)
// ============================================================================
module dcmem #(
    parameter MEM_ADDR_WIDTH = 5,
    parameter MEM_DATA_WIDTH = 16,
    parameter MEM_NUMBER     = 32
)(
    input                       clk,
    input                       MemWEn,
    input  [MEM_ADDR_WIDTH-1:0] addr,
    input  [MEM_DATA_WIDTH-1:0] dataw,
    output [MEM_DATA_WIDTH-1:0] datar
);
    reg [MEM_DATA_WIDTH-1:0] RAM [MEM_NUMBER-1:0];

    always @(posedge clk) begin
        if (MemWEn) begin
            RAM[addr] <= dataw;
        end
    end

    assign datar = RAM[addr];
endmodule

module icmem #(
    parameter PC_WIDTH  = 16,
    parameter ISA_WIDTH = 16
)(
    input                  clk,
    input                  rst,
    input                  inst_wen,
    input  [ISA_WIDTH-1:0] input_inst,
    output [ISA_WIDTH-1:0] current_inst,
    output [PC_WIDTH-1:0]  pc_out
);
    reg [PC_WIDTH-1:0] pc;
    assign pc_out = pc;

    always @(posedge clk or negedge rst) begin
        if (!rst)
            pc <= 16'd0;
        else
            pc <= pc + 16'd1;
    end

    dcmem #(
        .MEM_ADDR_WIDTH(5),
        .MEM_DATA_WIDTH(16),
        .MEM_NUMBER(32)
    ) inst_mem1 (
        .clk(clk),
        .MemWEn(inst_wen),
        .addr(pc[4:0]),
        .dataw(input_inst),
        .datar(current_inst)
    );
endmodule

// ============================================================================
// STEP 3: Arithmetic (MAC_ALU) and Multiplexer (MUX) Modules (Slide 19)
// ============================================================================
module MAC_ALU #(
    parameter REG_DATA_WIDTH = 16
)(
    input                       funct,
    input                       clk,
    input                       rst,
    input                       mac_en,
    input  [REG_DATA_WIDTH-1:0] rs1,
    input  [REG_DATA_WIDTH-1:0] rs2,
    output [REG_DATA_WIDTH-1:0] rd
);
    wire [REG_DATA_WIDTH-1:0] product;
    wire [REG_DATA_WIDTH-1:0] addend1, addend2;
    reg  [REG_DATA_WIDTH-1:0] psum;

    assign product = $signed(rs1) * $signed(rs2);
    assign addend1 = funct ? 16'd0 : product;
    assign addend2 = funct ? rs1   : psum;
    assign rd      = addend1 + addend2;

    always @(posedge clk or negedge rst) begin
        if (!rst)
            psum <= 16'd0;
        else if (mac_en)
            psum <= rd;
    end
endmodule

module MUX #(
    parameter WIDTH = 16
)(
    input  [1:0]       S,
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    input  [WIDTH-1:0] C,
    input  [WIDTH-1:0] D,
    output [WIDTH-1:0] Y
);
    assign Y = (S == 2'b00) ? A :
               (S == 2'b01) ? B :
               (S == 2'b10) ? C : D;
endmodule

// ============================================================================
// STEPS 5-9: Instruction Decoder & Immediate Generator (Slides 21-25)
// ============================================================================
module DECODER (
    input  [15:0] inst,
    output [3:0]  rd,
    output [3:0]  rs1,
    output [3:0]  rs2,
    output [4:0]  imm5,
    output [8:0]  imm9,
    output        funct,
    output reg    RegWEn,
    output reg    MemWEn,
    output reg    mac_en,
    output reg    mem_addr_sel,
    output reg [1:0] wb_sel
);
    wire [2:0] opcode = inst[15:13];

    assign rd    = inst[12:9];
    assign rs1   = inst[8:5];
    assign rs2   = inst[4:1];
    assign imm5  = inst[4:0];
    assign imm9  = inst[8:0];
    assign funct = inst[0];

    always @(*) begin
        RegWEn       = 1'b0;
        MemWEn       = 1'b0;
        mac_en       = 1'b0;
        mem_addr_sel = 1'b0;
        wb_sel       = 2'b00;

        case (opcode)
            3'b000: begin // Load: rd <- MEM[rs1 + imm5]
                RegWEn       = 1'b1;
                mem_addr_sel = 1'b0;
                wb_sel       = 2'b10;
            end
            3'b001: begin // Store: MEM[rs1] <- rs2
                MemWEn       = 1'b1;
                mem_addr_sel = 1'b1;
            end
            3'b010: begin // MOV: rd <- imm9
                RegWEn       = 1'b1;
                wb_sel       = 2'b01;
            end
            3'b011: begin // MAC: rd <- psum + rs1*rs2 (funct=0) or rd <- rs1 (funct=1)
                RegWEn       = 1'b1;
                mac_en       = 1'b1;
                wb_sel       = 2'b00;
            end
            default: ;
        endcase
    end
endmodule

// ============================================================================
// STEP 4: Top-Level AI Processor Core (Slides 20 & 25)
// ============================================================================
module ai_core_top (
    input         clk,
    input         rst,
    input         inst_wen,
    input  [15:0] input_inst,
    output [15:0] current_inst,
    output [15:0] pc_out,
    output [15:0] debug_wb_data
);
    wire [3:0]  rd, rs1, rs2;
    wire [4:0]  imm5;
    wire [8:0]  imm9;
    wire        funct, RegWEn, MemWEn, mac_en, mem_addr_sel;
    wire [1:0]  wb_sel;

    wire [15:0] rs1_data, rs2_data;
    wire [15:0] mac_out, dcm_datar, wb_data;
    wire [4:0]  load_addr, dcm_addr;

    assign debug_wb_data = wb_data;

    icmem u_icmem (
        .clk(clk),
        .rst(rst),
        .inst_wen(inst_wen),
        .input_inst(input_inst),
        .current_inst(current_inst),
        .pc_out(pc_out)
    );

    DECODER u_decoder (
        .inst(current_inst),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm5(imm5),
        .imm9(imm9),
        .funct(funct),
        .RegWEn(RegWEn),
        .MemWEn(MemWEn),
        .mac_en(mac_en),
        .mem_addr_sel(mem_addr_sel),
        .wb_sel(wb_sel)
    );

    regfile u_regfile (
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(rd),
        .rd_data(wb_data),
        .RegWEn(RegWEn),
        .clk(clk),
        .rst(rst),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    MAC_ALU u_mac_alu (
        .funct(funct),
        .clk(clk),
        .rst(rst),
        .mac_en(mac_en),
        .rs1(rs1_data),
        .rs2(rs2_data),
        .rd(mac_out)
    );

    assign load_addr = rs1_data[4:0] + imm5;

    MUX #(.WIDTH(5)) u_addr_mux (
        .S({1'b0, mem_addr_sel}),
        .A(load_addr),
        .B(rs1_data[4:0]),
        .C(5'd0),
        .D(5'd0),
        .Y(dcm_addr)
    );

    dcmem u_dcmem (
        .clk(clk),
        .MemWEn(MemWEn),
        .addr(dcm_addr),
        .dataw(rs2_data),
        .datar(dcm_datar)
    );

    MUX #(.WIDTH(16)) u_wb_mux (
        .S(wb_sel),
        .A(mac_out),
        .B({7'd0, imm9}),
        .C(dcm_datar),
        .D(16'd0),
        .Y(wb_data)
    );
endmodule

// ============================================================================
// TESTBENCH: Executes Slide 16 Neuron Program (Y = x1*w1 + x2*w2 + b)
// ============================================================================
module tb_ai_core;
    reg         clk;
    reg         rst;
    reg         inst_wen;
    reg  [15:0] input_inst;
    wire [15:0] current_inst;
    wire [15:0] pc_out;
    wire [15:0] debug_wb_data;

    integer trace_file;
    integer cycle;

    ai_core_top uut (
        .clk(clk),
        .rst(rst),
        .inst_wen(inst_wen),
        .input_inst(input_inst),
        .current_inst(current_inst),
        .pc_out(pc_out),
        .debug_wb_data(debug_wb_data)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_ai_core);
        trace_file = $fopen("sim_trace.csv", "w");
        $fwrite(trace_file, "cycle,pc,inst,R1,R2,R3,R4,R5,psum,MEM_ADY\n");

        clk = 0;
        rst = 0;
        inst_wen = 0;
        input_inst = 16'd0;

        // Initialize Data Memory: b=1, x1=2, x2=3, w1=4, w2=5
        uut.u_dcmem.RAM[0] = 16'd1; // MEM[ADB]   = b  = 1
        uut.u_dcmem.RAM[2] = 16'd2; // MEM[ADX]   = x1 = 2
        uut.u_dcmem.RAM[3] = 16'd3; // MEM[ADX+1] = x2 = 3
        uut.u_dcmem.RAM[4] = 16'd4; // MEM[ADW]   = w1 = 4
        uut.u_dcmem.RAM[5] = 16'd5; // MEM[ADW+1] = w2 = 5
        uut.u_dcmem.RAM[6] = 16'd0; // MEM[ADY]   = Y  = 0

        // Load 13-Instruction Neuron Assembly Program (Slide 16)
        uut.u_icmem.inst_mem1.RAM[0]  = 16'h4200; // MOV  R1, [ADB] (0)
        uut.u_icmem.inst_mem1.RAM[1]  = 16'h0420; // Load R2, R1, $0     -> R2 = b (1)
        uut.u_icmem.inst_mem1.RAM[2]  = 16'h6A41; // MAC  R5, R2, /, $1  -> R5 = b (1), psum = 1
        uut.u_icmem.inst_mem1.RAM[3]  = 16'h4202; // MOV  R1, [ADX] (2)
        uut.u_icmem.inst_mem1.RAM[4]  = 16'h4404; // MOV  R2, [ADW] (4)
        uut.u_icmem.inst_mem1.RAM[5]  = 16'h0620; // Load R3, R1, $0     -> R3 = x1 (2)
        uut.u_icmem.inst_mem1.RAM[6]  = 16'h0840; // Load R4, R2, $0     -> R4 = w1 (4)
        uut.u_icmem.inst_mem1.RAM[7]  = 16'h6A68; // MAC  R5, R3, R4, $0 -> R5 = 1 + 2*4 = 9
        uut.u_icmem.inst_mem1.RAM[8]  = 16'h0621; // Load R3, R1, $1     -> R3 = x2 (3)
        uut.u_icmem.inst_mem1.RAM[9]  = 16'h0841; // Load R4, R2, $1     -> R4 = w2 (5)
        uut.u_icmem.inst_mem1.RAM[10] = 16'h6A68; // MAC  R5, R3, R4, $0 -> R5 = 9 + 3*5 = 24
        uut.u_icmem.inst_mem1.RAM[11] = 16'h4206; // MOV  R1, [ADY] (6)
        uut.u_icmem.inst_mem1.RAM[12] = 16'h202A; // Store /, R1, R5     -> MEM[6] = 24

        #12 rst = 1;

        $display("\n================================================================================");
        $display(" Cycle | PC | Inst (Hex) |  R1 |  R2 |  R3 |  R4 |  R5 | psum | MEM[ADY] ");
        $display("--------------------------------------------------------------------------------");

        for (cycle = 0; cycle < 13; cycle = cycle + 1) begin
            @(posedge clk);
            #1; // Sample state right after clock edge
            $display("   %2d  | %2d |   0x%04h   | %3d | %3d | %3d | %3d | %3d | %4d |   %3d",
                     cycle, pc_out - 1, uut.u_icmem.inst_mem1.RAM[pc_out - 1],
                     uut.u_regfile.rf[1], uut.u_regfile.rf[2],
                     uut.u_regfile.rf[3], uut.u_regfile.rf[4],
                     uut.u_regfile.rf[5], uut.u_mac_alu.psum,
                     uut.u_dcmem.RAM[6]);
            $fwrite(trace_file, "%0d,%0d,0x%04h,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",
                    cycle, pc_out - 1, uut.u_icmem.inst_mem1.RAM[pc_out - 1],
                    uut.u_regfile.rf[1], uut.u_regfile.rf[2],
                    uut.u_regfile.rf[3], uut.u_regfile.rf[4],
                    uut.u_regfile.rf[5], uut.u_mac_alu.psum,
                    uut.u_dcmem.RAM[6]);
        end

        $display("================================================================================");
        $display("FINAL VERIFICATION: Y = x1*w1 + x2*w2 + b = (2*4) + (3*5) + 1 = 24");
        $display("Computed Register R5     = %0d", uut.u_regfile.rf[5]);
        $display("Computed Memory MEM[ADY] = %0d", uut.u_dcmem.RAM[6]);
        $display("================================================================================\n");
        $fclose(trace_file);
        $finish;
    end
endmodule
"""

with open("ai_processor.v", "w") as f:
    f.write(verilog_code)

# 3. Compile and Execute the Verilog Simulation
print("3/4: Compiling and executing Verilog simulation...")
subprocess.run("iverilog -o ai_sim ai_processor.v", shell=True, check=True)
sim_result = subprocess.run("vvp ai_sim", shell=True, capture_output=True, text=True, check=True)
print(sim_result.stdout)

# 4. Generate a Publication-Quality Timing Waveform Plot for the Homework Report
print("4/4: Generating hardware timing diagram (waveform.png)...")
data = np.genfromtxt("sim_trace.csv", delimiter=",", names=True, dtype=None, encoding="utf-8")
cycles = data["cycle"]

fig, axes = plt.subplots(6, 1, figsize=(12, 8), sharex=True)
fig.suptitle("Single-Cycle RISC AI Processor Simulation Waveforms (Neuron: Y = x1*w1 + x2*w2 + b)", fontsize=13, fontweight="bold")

signals = [
    ("pc", "PC (Program Counter)", "#1f77b4"),
    ("R1", "R1 (Addr Pointer)", "#ff7f0e"),
    ("R3", "R3 (Input x_i)", "#2ca02c"),
    ("R4", "R4 (Weight w_i)", "#d62728"),
    ("R5", "R5 / psum (MAC Accumulator)", "#9467bd"),
    ("MEM_ADY", "MEM[ADY] (Final Output Y)", "#8c564b")
]

for ax, (col, label, color) in zip(axes, signals):
    vals = data[col]
    ax.step(cycles, vals, where="post", color=color, linewidth=2.2)
    ax.set_ylabel(label, fontsize=9, fontweight="bold")
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.set_ylim(min(vals) - 1, max(vals) + 4)
    for c, v in zip(cycles, vals):
        ax.text(c + 0.15, v + 0.6, str(v), fontsize=8, color=color, fontweight="bold")

axes[-1].set_xlabel("Clock Cycle (Instruction Execution Step)", fontsize=11, fontweight="bold")
axes[-1].set_xticks(cycles)
plt.tight_layout(rect=[0, 0, 1, 0.96])
plt.savefig("waveform.png", dpi=300)
plt.show()
print("Done! Files generated in Colab sidebar: ai_processor.v, waveform.vcd, and waveform.png")