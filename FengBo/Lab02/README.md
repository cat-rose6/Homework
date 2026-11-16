
# RISC Processor Design and Matrix Multiplication

## 1. RISC Processor Design

The processor follows a simple single-cycle RISC architecture with a 16-bit instruction width and 16 general-purpose registers.

The processor consists of the following modules:

| Module | Function |
|---|---|
| `icmem` | Instruction memory and program counter |
| `regfile` | Register file with two read ports and one write port |
| `dcmem` | Data memory for input and output values |
| `MAC_ALU` | Multiply-accumulate arithmetic unit |
| `MUX` | Selects data for register writeback |
| `ai_core_top` | Connects the modules and implements instruction decoding |

The processor supports four instructions:

| Instruction | Opcode | Operation |
|---|---|---|
| LOAD | `001` | Load data from memory into a register |
| STORE | `010` | Store register data into memory |
| MOV | `011` | Move an immediate value into a register |
| MAC | `100` | Multiply-accumulate or initialize the accumulator |

Each instruction is 16 bits long, with a 3-bit opcode and additional fields for register addresses, immediate values, and function control.

The MAC unit is the main arithmetic component. When `funct=0`, it performs:

```math
psum_{\text{new}} = psum_{\text{old}} + rs1 \times rs2
```

When `funct=1`, the internal accumulator is cleared.

The main Verilog implementation is:

```verilog
assign product = $signed(rs1) * $signed(rs2);
assign addend1 = funct ? 0 : product;
assign addend2 = funct ? rs2 : psum;
assign rd = addend1 + addend2;
```

A `MACEn` signal is added to control accumulator updates, preventing other instructions from modifying the accumulated result.

The processor uses combinational logic for instruction decoding, register reading, and arithmetic operations. Registers, memory, and the program counter are updated on clock edges.

## 3. Scalar Matrix Multiplication

The required computation is:

```math
\begin{bmatrix}a&b\end{bmatrix}
\begin{bmatrix}A&B\\C&D\end{bmatrix}
=
\begin{bmatrix}aA+bC&aB+bD\end{bmatrix}
```

The two outputs are:

```math
y_0=aA+bC
```

```math
y_1=aB+bD
```

In `scalar.v`, each register stores one 16-bit value, and the MAC unit performs one multiplication and accumulation at a time.

The input values are stored in data memory:

| Address | Data |
|---|---|
| 0 | a |
| 1 | b |
| 2 | A |
| 3 | B |
| 4 | C |
| 5 | D |
| 6 | y0 |
| 7 | y1 |

The processor first loads the six input values into registers, then executes MAC instructions to calculate the two outputs separately.

For example, the first output is calculated using:

```text
MAC R7, R0, R0, 1   // Clear accumulator
MAC R7, R1, R3, 0   // a*A
MAC R7, R2, R5, 0   // a*A + b*C
```

The result is stored in memory using STORE. The same procedure is repeated for the second output.

The complete scalar program requires **16 instructions**, including loading, computation, and storing.

## 4. Vector Processor Extension

The vector processor extends the original scalar architecture using SIMD (Single Instruction, Multiple Data).

The register and data memory widths are increased from 16 bits to 32 bits, allowing each register to hold two 16-bit elements.

The MAC unit is extended to two parallel computation lanes:

```verilog
MAC_ALU_v lane0(
    .rs1(rs1[15:0]),
    .rs2(rs2[15:0]),
    ...
);

MAC_ALU_v lane1(
    .rs1(rs1[31:16]),
    .rs2(rs2[31:16]),
    ...
);
```

Both lanes execute the same instruction simultaneously but operate on different data.

For matrix multiplication, the inputs are organized as:

```math
X_0=[a,a],\quad X_1=[b,b]
```

```math
W_0=[A,B],\quad W_1=[C,D]
```

The first vector MAC computes:

```math
S_0=X_0\odot W_0=[aA,aB]
```

The second vector MAC computes:

```math
S_1=S_0+X_1\odot W_1
```

Therefore,

```math
\boxed{S_1=[aA+bC,\ aB+bD]}
```

where $\odot$ represents element-wise multiplication.

The vector processor retains the original four instructions and 16-bit instruction format. Only the data width and arithmetic hardware are extended.

The complete vector program requires **9 instructions**, compared with 16 instructions in the scalar implementation.

## 5. Simulation Results

The designs were simulated using **Icarus Verilog on EDA Playground**, with an independent Testbench (`tb.v`).

The Testbench generates the clock and reset signals, loads instructions and matrix data into memory, and checks the final results.

Two test cases were used.

**Test 1: Positive integer matrix**

```math
\begin{bmatrix}2&3\end{bmatrix}
\begin{bmatrix}4&5\\6&7\end{bmatrix}
=
\begin{bmatrix}26&31\end{bmatrix}
```

**Test 2: Matrix containing negative values**

```math
\begin{bmatrix}-2&3\end{bmatrix}
\begin{bmatrix}4&-5\\6&7\end{bmatrix}
=
\begin{bmatrix}10&31\end{bmatrix}
```

The simulation output was:

```text
Scalar result: [26, 31]
Vector result: [26, 31]
PASS: expected [26,31]

Scalar result: [10, 31]
Vector result: [10, 31]
PASS: expected [10,31]

ALL TESTS PASSED
```

Both processors produced the expected results for both test cases, confirming the correctness of the implemented instruction execution and matrix multiplication.
