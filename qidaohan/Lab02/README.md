本实验用 Verilog 搭建一个能执行 `MOV`、`LOAD`、`MAC`、`STORE` 的ISA。仿真程序验证它能计算 `2 × 4 + 3 × 5 + 1`，并把结果写进数据内存。

`ai_core_top.v`: 把取指、译码、寄存器、存储器和乘加单元连起来
`decoder.v`: 解析指令并产生控制信号
`blocks.v`: 寄存器堆、指令存储器、数据存储器和乘加单元
`tb_ai_core.v`: 放入程序和数据，检查实际结果

运行仿真需要 [Icarus Verilog](https://steveicarus.github.io/iverilog/)。本实验使用 13.0 版。确认终端能找到 `iverilog` 和 `vvp` 后，在 `Lab02` 文件夹中依次执行：

iverilog -g2012 -Wall -s tb_ai_core -o lab02_sim.vvp tb_ai_core.v ai_core_top.v decoder.v blocks.v
vvp lab02_sim.vvp

测试程序已内置在 `tb_ai_core.v`，不需要另外准备数据文件。看到 `PASS: mem[13] = 24 (expected 24)` 说明结果正确。