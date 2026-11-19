`timescale 1ns/1ps

// Turn the instruction into register indices, an immediate and control signals.
module decoder (
    input  wire [15:0] inst,
    output reg  [3:0]  rs1_addr, rs2_addr, rd_addr,
    output reg  [15:0] imm,
    output reg         reg_wen, mem_wen, mac_en, mac_init, use_offset,
    output reg  [1:0]  wb_sel
);
    localparam OP_LOAD  = 3'b001,
               OP_STORE = 3'b010,
               OP_MOV   = 3'b011,
               OP_MAC   = 3'b100;

    always @* begin
        rd_addr    = inst[12:9];
        rs1_addr   = inst[8:5];
        rs2_addr   = inst[4:1];
        imm        = 16'd0;
        reg_wen    = 1'b0;
        mem_wen    = 1'b0;
        mac_en     = 1'b0;
        mac_init   = 1'b0;
        use_offset = 1'b0;
        wb_sel     = 2'b00;

        case (inst[15:13])
            OP_LOAD: begin
                imm        = {{11{inst[4]}}, inst[4:0]};
                use_offset = 1'b1;
                reg_wen    = 1'b1;
                wb_sel     = 2'b00;  // Write back the memory read result.
            end
            OP_STORE: begin
                mem_wen    = 1'b1;   // Address from rs1, data from rs2.
            end
            OP_MOV: begin
                imm        = {{7{inst[8]}}, inst[8:0]};
                reg_wen    = 1'b1;
                wb_sel     = 2'b01;  // Write back the immediate.
            end
            OP_MAC: begin
                mac_en     = 1'b1;
                mac_init   = inst[0];
                reg_wen    = 1'b1;
                wb_sel     = 2'b10;  // Write back the accumulator result.
            end
            default: begin end       // Unused opcodes have no side effects.
        endcase
    end
endmodule
