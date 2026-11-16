module regfile #(
    parameter REG_ADDR_WIDTH = 4,
    parameter REG_DATA_WIDTH = 16,
    parameter REG_NUMBER = 16
)(
    input [REG_ADDR_WIDTH-1:0] rs1_addr,
    input [REG_ADDR_WIDTH-1:0] rs2_addr,
    input [REG_ADDR_WIDTH-1:0] rd_addr,
    input [REG_DATA_WIDTH-1:0] rd_data,
    input RegWEn,
    input clk, rst,
    output [REG_DATA_WIDTH-1:0] rs1_data,
    output [REG_DATA_WIDTH-1:0] rs2_data
);
    reg [REG_DATA_WIDTH-1:0] rf [REG_NUMBER-1:0];
    assign rs1_data = rs1_addr==0 ? 0 : rf[rs1_addr];
    assign rs2_data = rs2_addr==0 ? 0 : rf[rs2_addr];

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            integer i;
            for (i=0; i<REG_NUMBER; i=i+1) begin
                rf[i] <= 0;
            end
        end
        else if (RegWEn && rd_addr!=0)
            rf[rd_addr] <= rd_data;
    end
endmodule

module dcmem #(
    parameter MEM_ADDR_WIDTH=5,
    parameter MEM_DATA_WIDTH=16,
    parameter MEM_NUMBER=32
)(
    input clk,
    input MemWEn,
    input [MEM_ADDR_WIDTH-1:0] addr,
    input [MEM_DATA_WIDTH-1:0] dataw,
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
    parameter PC_WIDTH=16,
    parameter ISA_WIDTH=16
)(
    input clk,
    input rst,
    input inst_wen,
    input [ISA_WIDTH-1:0] input_inst,
    output [ISA_WIDTH-1:0] current_inst
);
    reg [PC_WIDTH-1:0] pc;
    always @(posedge clk or negedge rst)
        if (!rst)
            pc <= 0;
        else
            pc <= pc+1;
    dcmem inst_mem1(.clk(clk),
                    .MemWEn(inst_wen),
                    .addr(pc[4:0]),
                    .dataw(input_inst),
                    .datar(current_inst));
endmodule

module MAC_ALU #(
    parameter REG_DATA_WIDTH=16
)(
    input funct, clk,
    input MACEn,
    input [REG_DATA_WIDTH-1:0] rs1, rs2,
    output [REG_DATA_WIDTH-1:0] rd
);
    wire [REG_DATA_WIDTH-1:0] product;
    wire [REG_DATA_WIDTH-1:0] addend1, addend2;
    reg [REG_DATA_WIDTH-1:0] psum;

    assign product = $signed(rs1)*$signed(rs2);
    assign addend1 = funct ? 0 : product;
    assign addend2 = funct ? rs2 : psum;
    assign rd = addend1+addend2;

    always @(posedge clk) begin
        if (MACEn) begin
            if (funct)
                psum <= 0;
            else
                psum <= rd;
        end
    end
endmodule

module MUX(S,A,B,C,D,Y);
    input [1:0] S;
    input A,B,C,D;
    output Y;
    assign Y=(S==2'b00)? A : ((S==2'b01)? B : ((S==2'b10)? C : D));
endmodule

module ai_core_top(
    input clk,
    input rst,
    input inst_wen,
    input [15:0] input_inst
);
    wire [15:0] current_inst;
    wire [2:0] opcode = current_inst[15:13];
    wire [3:0] rd_field  = current_inst[12:9];
    wire [3:0] rs1_field = current_inst[8:5];
    wire [3:0] rs2_field = current_inst[4:1];
    wire [4:0] imm5      = current_inst[4:0];
    wire [8:0] imm9      = current_inst[8:0];
    wire funct           = current_inst[0];

    localparam LOAD=3'b001, STORE=3'b010, MOV=3'b011, MAC=3'b100;

    wire [3:0] rf_rs1_addr = (opcode==STORE) ? rd_field : rs1_field;
    wire [3:0] rf_rs2_addr = (opcode==STORE) ? rs1_field : rs2_field;
    wire [15:0] rs1_data, rs2_data;
    wire [15:0] mem_data, mac_data;
    wire [4:0] mem_addr = (opcode==LOAD) ? (rs1_data[4:0]+imm5) : rs1_data[4:0];
    wire [15:0] immediate_data = {7'b0,imm9};
    wire [15:0] rd_data;

    wire RegWEn = !inst_wen && rst &&
                  (opcode==LOAD || opcode==MOV || opcode==MAC);
    wire MemWEn = !inst_wen && rst && (opcode==STORE);
    wire MACEn  = !inst_wen && rst && (opcode==MAC);
    wire [1:0] mux_sel = (opcode==LOAD) ? 2'b00 :
                         (opcode==MOV)  ? 2'b01 :
                         (opcode==MAC)  ? 2'b10 : 2'b11;

    icmem u_icmem(.clk(clk), .rst(rst),
                  .inst_wen(inst_wen), .input_inst(input_inst),
                  .current_inst(current_inst));
    regfile u_rf(.rs1_addr(rf_rs1_addr), .rs2_addr(rf_rs2_addr),
                 .rd_addr(rd_field), .rd_data(rd_data),
                 .RegWEn(RegWEn), .clk(clk), .rst(rst),
                 .rs1_data(rs1_data), .rs2_data(rs2_data));
    dcmem u_dcm(.clk(clk), .MemWEn(MemWEn),
                .addr(mem_addr), .dataw(rs2_data), .datar(mem_data));
    MAC_ALU u_mac(.funct(funct), .clk(clk), .MACEn(MACEn),
                  .rs1(rs1_data), .rs2(rs2_data), .rd(mac_data));

    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin : writeback_mux
            MUX u_mux(.S(mux_sel), .A(mem_data[i]), .B(immediate_data[i]),
                      .C(mac_data[i]), .D(1'b0), .Y(rd_data[i]));
        end
    endgenerate
endmodule
