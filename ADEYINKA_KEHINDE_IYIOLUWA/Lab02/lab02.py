# Lab02 - Introduction of Intelligent Computing Chip and System
# Adeyinka Kehinde Iyioluwa | Tongji University
# Run after installing dependencies in README.md
# TinyAI-16 FINAL: Reproduce the homework verification and FPGA results
# Run in ONE Python cell in Google Colab (CPU runtime; no uploads needed).
# Includes the neuron test, six extended RTL tests, generic logic
# synthesis, FPGA synthesis, place-and-route, timing, bitstream, graphs, and ZIP.
import subprocess, re, json, zipfile, shutil, csv
from pathlib import Path

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / 'outputs'
BUILD.mkdir(parents=True, exist_ok=True)

print('Checking Icarus Verilog, Yosys, nextpnr and IceStorm...')
missing = [t for t in ('iverilog','vvp','yosys','nextpnr-ice40','icepack') if not shutil.which(t)]
if missing:
    raise SystemExit('Required system tools missing: ' + ', '.join(missing) +
        '. Install with: sudo apt-get install -y iverilog yosys nextpnr-ice40 fpga-icestorm')

CPU = r'''`timescale 1ns/1ps
module tinyai16_cpu (
  input wire clk, reset_n,
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
  wire [15:0] imm9 = {{7{inst[8]}}, inst[8:0]};
  wire [15:0] imm5 = {{11{inst[4]}}, inst[4:0]};
  wire [15:0] full_addr = regs[rs1] + imm5;
  wire [5:0] addr = full_addr[5:0];
  wire signed [31:0] product =
      $signed(regs[rs1]) * $signed(regs[rs2]);

  assign pc_out = pc;

  // The HEX files contain every word in ROM and RAM.
  // Use one initialization source for synthesis and simulation.
  initial begin
    $readmemh("program.hex", imem);
    $readmemh("data.hex", dmem);
  end

  integer i;
  always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      pc <= 0;
      halted <= 0;
      for (i=0; i<16; i=i+1)
        regs[i] <= 0;
    end else if (!halted) begin
      pc <= pc+8'd1;
      case (opcode)
        3'd0: if (rd!=0)
          regs[rd] <= imm9;                       // MOVI
        3'd1: if (rd!=0)
          regs[rd] <= dmem[addr];                 // LOAD
        3'd2:
          dmem[addr] <= regs[rd];                 // STORE
        3'd3: if (rd!=0)
          regs[rd] <= regs[rs1]+regs[rs2];       // ADD
        3'd4: if (rd!=0)
          regs[rd] <= regs[rs1]-regs[rs2];       // SUB
        3'd5: if (rd!=0)
          regs[rd] <= regs[rd]+product[15:0];    // MAC
        3'd6: if (regs[rd]!=0)
          pc <= pc+8'd1+imm9[7:0];               // BNZ
        3'd7: begin
          halted <= 1;
          pc <= pc;
        end                                       // HALT
      endcase
    end
  end
endmodule
'''

MAIN_TB = r'''`timescale 1ns/1ps
module tb;
  reg clk=0, reset_n=0;
  wire halted;
  wire [7:0] pc;
  integer cycles;

  tinyai16_cpu dut(
    .clk(clk),
    .reset_n(reset_n),
    .halted(halted),
    .pc_out(pc)
  );

  always #5 clk=~clk;

  initial begin
    $dumpfile("outputs/tinyai16.vcd");
    $dumpvars(0,tb);

    #12 reset_n=1;

    for(cycles=1; cycles<=80; cycles=cycles+1) begin
      @(posedge clk);
      #1;

      if(halted) begin
        $display(
          "HALT after %0d cycles, PC=%0d, neuron=%0d",
          cycles,pc,$signed(dut.dmem[16])
        );

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

        $display(
          "PASS: TinyAI-16 neuron=27, register, memory, MAC and branch checks"
        );
        $finish;
      end
    end

    $fatal(1,"FAIL: no HALT within 80 cycles");
  end
endmodule
'''

EXTENDED_TB = r'''`timescale 1ns/1ps
module tb;
  reg clk=0, reset_n=0;
  wire halted;
  wire [7:0] pc;
  integer cycles;
  tinyai16_cpu dut(.clk(clk),.reset_n(reset_n),.halted(halted),.pc_out(pc));
  always #5 clk=~clk;
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0,tb);
    #12 reset_n=1;
    for(cycles=1; cycles<=400; cycles=cycles+1) begin
      @(posedge clk); #1;
      if(halted) begin
        $display("RESULT cycles=%0d pc=%0h r0=%0h r1=%0h r2=%0h r4=%0h r6=%0h r7=%0h r8=%0h r9=%0h r11=%0h r12=%0h mem0=%0h mem16=%0h mem17=%0h mem63=%0h",
           cycles,pc,dut.regs[0],dut.regs[1],dut.regs[2],dut.regs[4],dut.regs[6],dut.regs[7],dut.regs[8],dut.regs[9],dut.regs[11],dut.regs[12],dut.dmem[0],dut.dmem[16],dut.dmem[17],dut.dmem[63]);
        $finish;
      end
    end
    $fatal(1,"Timed out without HALT");
  end
endmodule
'''

CASES = {
  1: dict(prog='0204 2420 2621 080c 2a80 2c81 0e08 30e0 b04a b06c 1210 5120',
          data={4:'fffd',5:'0002',8:'fff9',12:'0004',13:'fffb'},
          expect={'cycles':13,'pc':12,'r8':0xffe3,'mem16':0xffe3}),
  2: dict(prog='0200 2420 2621 6846 2a22 2c23 6eac 1410 4940 4f41',
          data={0:'7fff',1:'0001',2:'8000',3:'ffff'},
          expect={'cycles':11,'pc':10,'r4':0x8000,'r7':0x7fff,'mem16':0x8000,'mem17':0x7fff}),
  3: dict(prog='0200 2420 2621 8846 2a22 2c23 8eac 1410 4940 4f41',
          data={0:'8000',1:'0001',2:'7fff',3:'ffff'},
          expect={'cycles':11,'pc':10,'r4':0x7fff,'r7':0x8000,'mem16':0x7fff,'mem17':0x8000}),
  4: dict(prog='0200 1000 2420 2621 b046 2822 2a23 b08a 1410 5140 2c24 2e25 b2ce 5341',
          data={0:'012c',1:'012c',2:'ff38',3:'00c8',4:'8000',5:'ffff'},
          expect={'cycles':15,'pc':14,'r8':0xc350,'r9':0x8000,'mem16':0xc350,'mem17':0x8000}),
  5: dict(prog='007b 0300 04ff 0600 083f 0a2a 4a81 2c81 0e0f 4af0 30f0 1203 1401 9334 d3fe d201 164d 19ff',
          data={}, expect={'cycles':23,'pc':18,'r0':0,'r1':0xff00,'r2':255,'r6':42,'r8':42,'r9':0,'r11':77,'r12':0xffff,'mem0':42,'mem63':42}),
  6: dict(prog='0201 c2fd e000', data={}, special={255:'c302'},
          expect={'cycles':4,'pc':2,'r1':1,'r0':0}),
}

(ROOT/'tinyai16_cpu.v').write_text(CPU)
(ROOT/'tb_main.v').write_text(MAIN_TB)
(ROOT/'tb_extended.v').write_text(EXTENDED_TB)

def memory_files(words, entries):
    rom = ['e000'] * 256
    assert len(words) <= 256
    rom[:len(words)] = [w.lower() for w in words]
    ram = ['0000'] * 64
    for index, value in entries.items():
        ram[index] = f'{value & 0xffff:04x}' if isinstance(value,int) else value.lower()
    (ROOT/'program.hex').write_text('\n'.join(rom) + '\n')
    (ROOT/'data.hex').write_text('\n'.join(ram) + '\n')

def run(name, cmd):
    result=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    log=result.stdout + '\n' + result.stderr
    (BUILD/(name+'.log')).write_text(log)
    print(f'{name}:', 'PASS' if result.returncode==0 else 'FAILED')
    if result.returncode:
        print('\n'.join(log.splitlines()[-25:]))
    return result.returncode,log

# STEP 1: Reproduce original self-checking neuron simulation.
neur_program = '''0063 0204 2420 2621 080c 2a80 2c81 0e08 30e0 b04a b06c
1210 5120 1403 1601 9556 d5fe 7916 1bf9 bb76 1c0e 3fdf 1c12
59df e000'''.split()
neur_data = {4:2, 5:4, 8:1, 12:3, 13:5}
memory_files(neur_program,neur_data)
rc,_=run('01_main_compile',['iverilog','-g2012','-s','tb','-o','outputs/main_sim',
                            'tinyai16_cpu.v','tb_main.v'])
assert rc==0, 'Main testbench did not compile'
rc,log=run('02_main_simulation',['vvp','outputs/main_sim'])
assert rc==0 and 'PASS: TinyAI-16' in log, 'Original neuron RTL test FAILED'
print('  Original neuron result: 27, 29 cycles, HALT at PC=24')
shutil.copy2(BUILD/'tinyai16.vcd',BUILD/'main_neuron.vcd')

# STEP 2: Run all six edge-case RTL programs against the same processor.
# VCD output from the extended bench is wave.vcd in the project directory.
rc,_=run('03_extended_compile',['iverilog','-g2012','-s','tb',
                                '-o','outputs/extended_sim',
                                'tinyai16_cpu.v','tb_extended.v'])
assert rc==0, 'Extended Verilog testbench failed compilation'
rows=[]
for number, case in CASES.items():
    special=case.get('special',{})
    rom=['e000']*256
    for j,w in enumerate(case['prog'].split()): rom[j]=w
    for address,w in special.items(): rom[address]=w
    ram=['0000']*64
    for address,w in case['data'].items(): ram[address]=w
    (ROOT/'program.hex').write_text('\n'.join(rom)+'\n')
    (ROOT/'data.hex').write_text('\n'.join(ram)+'\n')
    rc,log=run(f'04_edge_case_{number}', ['vvp','outputs/extended_sim'])
    assert rc==0, f'Extended case {number} stopped with error'
    match=re.search(r'^RESULT (.+)$',log,re.M)
    assert match, f'Extended case {number} did not return a result'
    values={k:int(v,10 if k=='cycles' else 16)
            for k,v in re.findall(r'(\w+)=(\w+)',match.group(1))}
    for field,expected in case['expect'].items():
        assert values[field]==expected, f'Case {number} {field}: got {values[field]}, expected {expected}'
    rows.append({'case':number,'cycles':values['cycles'],'halt_pc':values['pc'],'pass':True})
    shutil.copy2(ROOT/'wave.vcd',BUILD/f'extended_case_{number}.vcd')
    print(f'   CASE {number} VERIFIED: {values["cycles"]} cycles')
print('ALL SIX EXTENDED RTL CASES PASSED')
with (BUILD/'edge_case_summary.csv').open('w',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=['case','cycles','halt_pc','pass'])
    writer.writeheader();writer.writerows(rows)

# STEP 3: Restore the original neuron program for FPGA synthesis.
memory_files(neur_program,neur_data)
summary={
    'main_neuron_RTL_pass':True,
    'six_extended_RTL_cases_pass':True,
    'FPGA_target':'iCE40 HX8K CT256',
    'requested_clock_MHz':10,
    'FPGA_synthesis_pass':False,
    'FPGA_place_route_pass':False,
    'FPGA_bitstream_created':False,
    'real_FPGA_board_tested':False,
    'OpenLane_physical_design_completed':False
}
rc,log=run('05_fpga_synthesis',[
    'yosys','-p','read_verilog tinyai16_cpu.v; '
    'hierarchy -check -top tinyai16_cpu; '
    'synth_ice40 -top tinyai16_cpu -json outputs/tinyai16.json; stat'])
summary['FPGA_synthesis_pass']=(rc==0 and (BUILD/'tinyai16.json').is_file())

if summary['FPGA_synthesis_pass']:
    rc,log=run('06_fpga_place_route',[
        'nextpnr-ice40','--hx8k','--package','ct256',
        '--json','outputs/tinyai16.json','--asc','outputs/tinyai16.asc',
        '--freq','10','--pcf-allow-unconstrained'])
    summary['FPGA_place_route_pass']=(rc==0 and (BUILD/'tinyai16.asc').is_file())
    freqs=re.findall(r'Max frequency for clock[^:]*:\s*([0-9.]+)\s*MHz',log)
    if freqs: summary['estimated_Fmax_MHz']=float(freqs[-1])

if summary['FPGA_place_route_pass']:
    rc,_=run('07_fpga_bitstream',[ 'icepack','outputs/tinyai16.asc','outputs/tinyai16.bin'])
    summary['FPGA_bitstream_created']=(rc==0 and (BUILD/'tinyai16.bin').is_file())

# STEP 4: Also run technology-independent ASIC-precursor logic synthesis.
# This is NOT OpenLane physical-design/tapeout; it requires different tools.
rc,_=run('08_generic_synthesis',[ 'yosys','-p',
    'read_verilog tinyai16_cpu.v; hierarchy -check -top tinyai16_cpu; '
    'synth -top tinyai16_cpu -flatten; '
    'write_verilog -noattr outputs/generic_netlist.v; stat'])
summary['generic_logic_synthesis_pass']=rc==0
(ROOT/'results.json').write_text(json.dumps(summary,indent=2))
(ROOT/'hardware_note.txt').write_text(
    'Software-only FPGA implementation. No FPGA board was used. '
    'No board-specific pin constraints were supplied; the bitstream is NOT '
    'ready to flash onto a board. OpenLane/ASIC physical layout is not a\n'
    'result of this script; generic synthesis only.\n')
print('\nFINAL SUMMARY\n',json.dumps(summary,indent=2))

# STEP 5: Make graphs from the results obtained by THIS run.
try:
    import matplotlib.pyplot as plt
    fig,ax=plt.subplots(figsize=(8,4))
    ax.bar([f'Case {r["case"]}' for r in rows],[r['cycles'] for r in rows])
    ax.set_ylabel('Executed instructions / cycles')
    ax.set_title('TinyAI-16: Six extended RTL verification cases')
    fig.tight_layout();fig.savefig(BUILD/'extended_cycle_counts.png',dpi=180)
    plt.close(fig)
    if 'estimated_Fmax_MHz' in summary:
        fig,ax=plt.subplots(figsize=(5.5,4))
        ax.bar(['Target clock','Estimated Fmax'],
               [10,summary['estimated_Fmax_MHz']])
        ax.set_ylabel('MHz')
        ax.set_title('TinyAI-16 FPGA timing analysis')
        fig.tight_layout();fig.savefig(BUILD/'fpga_timing_result.png',dpi=180)
        plt.close(fig)
except Exception as graph_error:
    (BUILD/'plot_error.txt').write_text(str(graph_error))



# STEP 5B: Extract waveform and actual FPGA resource measurements for report plots.
def read_pc_trace(vcd_path):
    """Read testbench-level PC changes from an Icarus Verilog VCD (1 ps timescale)."""
    vcd_path = Path(vcd_path)
    if not vcd_path.is_file():
        return [], []
    lines = vcd_path.read_text(errors='replace').splitlines()
    stack = []
    ident = None
    data_start = None
    for idx, line in enumerate(lines):
        cols = line.split()
        if len(cols) >= 3 and cols[:2] == ['$scope', 'module']:
            stack.append(cols[2])
        elif cols and cols[0] == '$upscope':
            if stack: stack.pop()
        elif cols and cols[0] == '$var' and len(cols) >= 6:
            # tb.pc is deliberately preferred over dut.pc
            if stack == ['tb'] and cols[4] == 'pc':
                ident = cols[3]
        elif cols and cols[0] == '$enddefinitions':
            data_start = idx + 1
            break
    if ident is None or data_start is None:
        return [], []
    curr_ps = 0
    times, values = [], []
    for line in lines[data_start:]:
        line = line.strip()
        if line.startswith('#') and line[1:].isdigit():
            curr_ps = int(line[1:])
        elif line.startswith('b'):
            fields = line[1:].split()
            if len(fields) == 2 and fields[1] == ident and set(fields[0]) <= {'0','1'}:
                times.append(curr_ps/1000)   # nanoseconds
                values.append(int(fields[0], 2))
    return times, values

try:
    import matplotlib.pyplot as plt
    for vcd, output, title in [
        ('main_neuron.vcd', 'neuron_pc_trace.png', 'Original neuron program: PC waveform'),
        ('extended_case_6.vcd', 'branch_pc_trace.png', 'Extended case 6: branch to 255 and back')
    ]:
        ts, pc_values = read_pc_trace(BUILD / vcd)
        if ts:
            fig, ax = plt.subplots(figsize=(8,3.5))
            ax.step(ts, pc_values, where='post', marker='.', markersize=4)
            ax.set(title=title, xlabel='Simulation time (ns)', ylabel='Program counter')
            ax.grid(True, alpha=0.3)
            fig.tight_layout()
            fig.savefig(BUILD / output, dpi=180)
            plt.close(fig)
except Exception as e:
    (BUILD / 'vcd_plot_error.txt').write_text(repr(e))

if (BUILD / '06_fpga_place_route.log').exists():
    placement_log = (BUILD / '06_fpga_place_route.log').read_text(errors='replace')
    resources = {}
    for key in ('ICESTORM_LC','ICESTORM_RAM'):
        m = re.search(r'\b' + key + r':\s*(\d+)\s*/\s*(\d+)', placement_log)
        if m:
            resources[key] = {'used': int(m.group(1)), 'available': int(m.group(2))}
    if resources:
        summary['fpga_resources'] = resources
        (BUILD / 'fpga_resources.json').write_text(json.dumps(resources, indent=2))
        try:
            import matplotlib.pyplot as plt
            if 'ICESTORM_LC' in resources:
                r = resources['ICESTORM_LC']
                fig, ax = plt.subplots(figsize=(6,3.5))
                ax.bar(['Used', 'Available'], [r['used'], r['available']])
                ax.set(title='iCE40 HX8K logic-cell utilization', ylabel='Logic cells')
                fig.tight_layout()
                fig.savefig(BUILD / 'fpga_logic_resources.png', dpi=180)
                plt.close(fig)
        except Exception as e:
            (BUILD / 'resource_plot_error.txt').write_text(repr(e))

# The final summary is written again so parsed FPGA resources are included.
(ROOT/'results.json').write_text(json.dumps(summary, indent=2))

# STEP 6: Download complete reproducible logs, waveforms, and source.
result_zip=ROOT/'Lab02_All_Results.zip'
with zipfile.ZipFile(result_zip,'w',zipfile.ZIP_DEFLATED) as z:
    for p in ROOT.rglob('*'):
        if p.is_file() and p != result_zip: z.write(p,p.relative_to(ROOT))
print('Results saved at:', result_zip)
