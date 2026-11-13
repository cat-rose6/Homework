
`timescale 1ns/1ps
module tb;
reg clk=0, reset_n=0;
wire halted;
wire [7:0] pc;
integer cycles;

tinyai16_cpu dut(
    .clk(clk), .reset_n(reset_n),
    .halted(halted), .pc_out(pc)
);
always #5 clk=~clk;

initial begin
    $dumpfile("build/neuron.vcd");
    $dumpvars(0,tb);
    #12 reset_n=1;

    for(cycles=1;cycles<=80;cycles=cycles+1) begin
        @(posedge clk); #1;
        if(halted) begin
            $display("HALT after %0d cycles, PC=%0d, neuron=%0d",
                cycles,pc,$signed(dut.dmem[16]));

            if(dut.dmem[16] !== 16'd27 ||
               dut.dmem[17] !== 16'd28 ||
               dut.regs[0] !== 16'd0 ||
               dut.regs[8] !== 16'd27 ||
               dut.regs[10] !== 16'd0 ||
               dut.regs[12] !== 16'd28 ||
               dut.regs[13] !== 16'hfffa ||
               dut.regs[15] !== 16'd5 ||
               pc !== 8'd24)
                $fatal(1,"FAIL: architectural state mismatch");

            $display("PASS: TinyAI-16 neuron=27");
            $finish;
        end
    end
    $fatal(1,"FAIL: Processor did not halt");
end
endmodule
