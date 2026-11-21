// 16 位单周期处理器，地址以 16 位字为单位。
package simple_isa;
    // 操作码位于指令的高 3 位，编码 100 至 111 保留。
    localparam [2:0] OP_LOAD  = 3'b000,
                     OP_STORE = 3'b001,
                     OP_MOV   = 3'b010,
                     OP_MAC   = 3'b011;
endpackage

module regfile #(
    parameter REG_ADDR_WIDTH = 4, REG_DATA_WIDTH = 16, REG_NUMBER = 16
) (
    input  wire [REG_ADDR_WIDTH-1:0] rs1_addr, rs2_addr, rd_addr,
    input  wire [REG_DATA_WIDTH-1:0] rd_data,
    input  wire RegWEn, clk, rst,
    output wire [REG_DATA_WIDTH-1:0] rs1_data, rs2_data
);
    reg [REG_DATA_WIDTH-1:0] rf [0:REG_NUMBER-1];
    assign rs1_data = rs1_addr == 0 ? 0 : rf[rs1_addr];
    assign rs2_data = rs2_addr == 0 ? 0 : rf[rs2_addr];

    integer i;
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < REG_NUMBER; i = i + 1)
                rf[i] <= 0;
        end else if (RegWEn && rd_addr != 0) begin
            rf[rd_addr] <= rd_data;
        end
    end
endmodule

module dcmem #(
    parameter MEM_ADDR_WIDTH = 5, MEM_DATA_WIDTH = 16, MEM_NUMBER = 32
) (
    input  wire clk, MemWEn,
    input  wire [MEM_ADDR_WIDTH-1:0] addr,
    input  wire [MEM_DATA_WIDTH-1:0] dataw,
    output wire [MEM_DATA_WIDTH-1:0] datar
);
    reg [MEM_DATA_WIDTH-1:0] RAM [0:MEM_NUMBER-1];
    always @(posedge clk)
        if (MemWEn)
            RAM[addr] <= dataw;
    assign datar = RAM[addr];
endmodule

module icmem #(
    parameter PC_WIDTH = 16, ISA_WIDTH = 16
) (
    input  wire clk, rst, inst_wen,
    input  wire [ISA_WIDTH-1:0] input_inst,
    output wire [ISA_WIDTH-1:0] current_inst
);
    reg [PC_WIDTH-1:0] pc;
    always @(posedge clk or negedge rst)
        if (!rst)
            pc <= 0;
        else
            pc <= pc + 1'b1;

    // 指令 RAM 有 32 个字，使用 PC 的低 5 位寻址。
    wire [4:0] inst_addr = pc;
    dcmem #(.MEM_DATA_WIDTH(ISA_WIDTH)) inst_mem1 (
        .clk(clk), .MemWEn(rst && inst_wen), .addr(inst_addr),
        .dataw(input_inst), .datar(current_inst)
    );
endmodule

module MAC_ALU #(parameter REG_DATA_WIDTH = 16) (
    input  wire funct, clk, rst, mac_en,
    input  wire [REG_DATA_WIDTH-1:0] rs1, rs2,
    output wire [REG_DATA_WIDTH-1:0] rd
);
    reg  [REG_DATA_WIDTH-1:0] psum;
    wire [REG_DATA_WIDTH-1:0] product = $signed(rs1) * $signed(rs2);
    // funct=1 时用 rs1 初始化累加器，funct=0 时累加乘积并保留低 16 位。
    assign rd = funct ? rs1 : psum + product;
    always @(posedge clk or negedge rst)
        if (!rst)
            psum <= 0;
        else if (mac_en)
            psum <= rd;
endmodule

module MUX #(parameter WIDTH = 1) (
    input  wire [1:0] S,
    input  wire [WIDTH-1:0] A, B, C, D,
    output wire [WIDTH-1:0] Y
);
    assign Y = (S == 2'b00) ? A : (S == 2'b01) ? B : (S == 2'b10) ? C : D;
endmodule

module decoder (
    input  wire [15:0] inst,
    output wire [3:0] rd, rs1, rs2,
    output wire funct,
    output wire [4:0] offset,
    output wire [15:0] immediate,
    output reg RegWEn, MemWEn, mac_en,
    output reg [1:0] wb_sel
);
    import simple_isa::*;
    assign rd    = inst[12:9];
    assign rs1   = inst[8:5];
    assign rs2   = inst[4:1];
    assign funct = inst[0];
    assign offset = inst[4:0];
    assign immediate = {{7{inst[8]}}, inst[8:0]};  // MOV 使用有符号 9 位立即数

    always @* begin
        RegWEn = 0;
        MemWEn = 0;
        mac_en = 0;
        wb_sel = 0;
        case (inst[15:13])
            OP_LOAD:  RegWEn = 1;
            OP_STORE: MemWEn = 1;
            OP_MOV: begin
                RegWEn = 1;
                wb_sel = 1;
            end
            OP_MAC: begin
                RegWEn = 1;
                wb_sel = 2;
                mac_en = 1;
            end
            default: ;  // 保留编码无写操作
        endcase
    end
endmodule

// 装载：先将 rst 拉低清零 PC，再释放 rst，保持 inst_wen=1，每拍写一个字。
// 执行：再次拉低 rst，将 inst_wen 置 0，再释放 rst，从地址 0 每拍执行一条。
// STORE 生效的上升沿可通过 data_wen、data_addr 和 data_wdata 观察写事务。
module ai_core_top (
    input  wire clk, rst, inst_wen,
    input  wire [15:0] input_inst,
    output wire data_wen,
    output wire [4:0] data_addr,
    output wire [15:0] data_wdata
);
    wire [15:0] inst, rs1_data, rs2_data, mem_data, mac_data, imm, rd_data;
    wire [3:0] rd, rs1, rs2;
    wire [4:0] offset;
    wire [1:0] wb_sel;
    wire funct, reg_write, mem_write, mac_en;
    wire executing = rst && !inst_wen;

    icmem imem (.clk(clk), .rst(rst), .inst_wen(inst_wen),
                .input_inst(input_inst), .current_inst(inst));
    decoder dec (.inst(inst), .rd(rd), .rs1(rs1), .rs2(rs2), .funct(funct),
                 .offset(offset), .immediate(imm), .RegWEn(reg_write),
                 .MemWEn(mem_write), .mac_en(mac_en), .wb_sel(wb_sel));
    regfile regs (.clk(clk), .rst(rst), .RegWEn(executing && reg_write),
                  .rs1_addr(rs1), .rs2_addr(rs2), .rd_addr(rd),
                  .rs1_data(rs1_data), .rs2_data(rs2_data), .rd_data(rd_data));

    // LOAD 使用基址加 5 位偏移（模 32）；STORE 直接使用 rs1 的地址。
    assign data_addr = mem_write ? rs1_data[4:0] : rs1_data[4:0] + offset;
    assign data_wdata = rs2_data;
    assign data_wen = executing && mem_write;
    dcmem dmem (.clk(clk), .MemWEn(data_wen), .addr(data_addr),
                .dataw(data_wdata), .datar(mem_data));
    MAC_ALU alu (.clk(clk), .rst(rst), .mac_en(executing && mac_en),
                 .funct(funct), .rs1(rs1_data), .rs2(rs2_data), .rd(mac_data));
    MUX #(.WIDTH(16)) writeback (.S(wb_sel), .A(mem_data), .B(imm),
                                 .C(mac_data), .D(16'd0), .Y(rd_data));
endmodule
