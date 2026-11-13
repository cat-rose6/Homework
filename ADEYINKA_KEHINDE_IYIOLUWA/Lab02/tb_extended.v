
`timescale 1ns/1ps
module tb;
reg clk=0,reset_n=0;
wire halted;
wire [7:0] pc;
integer cycles;

tinyai16_cpu dut(
    .clk(clk), .reset_n(reset_n),
    .halted(halted), .pc_out(pc)
);
always #5 clk=~clk;

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,tb);
    #12 reset_n=1;

    for(cycles=1;cycles<=400;cycles=cycles+1) begin
        @(posedge clk); #1;
        if(halted) begin
            $display(
              "RESULT cycles=%0d pc=%0h r0=%0h r1=%0h r2=%0h r4=%0h r6=%0h r7=%0h r8=%0h r9=%0h r11=%0h r12=%0h mem0=%0h mem16=%0h mem17=%0h mem63=%0h",
              cycles,pc,dut.regs[0],dut.regs[1],
              dut.regs[2],dut.regs[4],dut.regs[6],
              dut.regs[7],dut.regs[8],dut.regs[9],
              dut.regs[11],dut.regs[12],dut.dmem[0],
              dut.dmem[16],dut.dmem[17],dut.dmem[63]
            );
            $finish;
        end
    end
    $fatal(1,"Timeout without HALT");
end
endmodule
