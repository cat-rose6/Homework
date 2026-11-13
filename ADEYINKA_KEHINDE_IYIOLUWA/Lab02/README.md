# Lab 02 — Custom 16-Bit RISC Instruction Set Architecture

**Student:** Adeyinka Kehinde Iyioluwa  
**University:** Tongji University  
**Course:** Introduction of Intelligent Computing Chip and System  
**Lab:** 02 — Design, Verilog Implementation, Simulation, and FPGA Feasibility  

## Objective

Design a custom 16-bit RISC instruction-set architecture, implement its processor in synthesizable Verilog, and verify it through directed simulations and software-only FPGA place-and-route. The custom processor provides 16 16-bit registers, an 8-bit PC and eight instructions: `MOVI`, `LOAD`, `STORE`, `ADD`, `SUB`, `MAC`, `BNZ`, and `HALT`.

## Results

The baseline test computes `Y = x1*w1 + x2*w2 + b = 2*3 + 4*5 + 1 = 27`. RTL simulation: **PASS**, 29 cycles. Six additional signed arithmetic, memory, overflow and branch tests: **6/6 PASS**. The iCE40 HX8K CT256 virtual FPGA implementation completed synthesis, routing and bitstream packing; 3,279/7,680 logic cells (42.7%), estimated maximum clock **35.55 MHz** against the requested **10 MHz**. Generic ASIC logic synthesis also completed. No physical board or ASIC chip was tested.

## Files

- `Lab_2_Final.pdf` — submission-ready laboratory report, including graphs
- `lab02.py` — complete reproducible Python orchestration script
- `tinyai16_cpu.v` — 16-bit RTL processor
- `tb_main.v`, `tb_extended.v` — self-checking Verilog testbenches
- `program.hex`, `data.hex` — baseline program and memory data
- `figures/` — simulation and FPGA timing/resource graphs
- `evidence/` — verification summary, selected logs and synthesis results
- `requirements.txt` — Python graphing dependency

## How to run

On **Google Colab** (CPU runtime), run the following system-dependency installation in a cell, then upload the `Lab02` folder files (or clone your fork) and run `lab02.py`:

```bash
!apt-get update -qq
!apt-get install -y -qq iverilog yosys nextpnr-ice40 fpga-icestorm
!pip install -q -r requirements.txt
!python lab02.py
```

On **Ubuntu/Debian Linux**, install the system tools and Python package first:

```bash
sudo apt-get update
sudo apt-get install -y iverilog yosys nextpnr-ice40 fpga-icestorm
python3 -m pip install -r requirements.txt
python3 lab02.py
```

The script saves fresh logs, VCD waveforms, plots and synthesis artifacts under `outputs/` and creates `Lab02_All_Results.zip` locally. Run from the folder containing `lab02.py`. The script re-generates the Verilog and baseline memory image for reproducibility.

## Submission location

Submit the unzipped contents of this folder through your course GitHub workflow at:

`cat-rose6/Homework` → `ADEYINKA_KEHINDE_IYIOLUWA/Lab02`

Fork the course repository, add this `Lab02` folder alongside your earlier `Lab01`, and open a pull request titled **`Lab02 - Adeyinka Kehinde Iyioluwa`**. Do not upload a single ZIP as the GitHub submission. Only publish work you are permitted to share and follow any additional instructor requirements.

## Scope note

The FPGA timing estimate and configuration file are outputs from computer-aided design software. They are **not** measurements from an FPGA board. The bitstream was created without board-specific validated pin constraints, so it must not be flashed as-is onto a board. No ASIC GDSII physical layout was completed.

## Naming note

The laboratory report uses the neutral title **Custom 16-Bit RISC Processor**. Some original RTL and script filenames retain `tinyai16` as an internal identifier for reproducibility; this does not affect instruction encoding or execution.
