# AXI Stream Systolic Array

```
# Matrices:
k: (K,C) # Weights
x: (K,R) # Inputs
a: (C,R) # Partial sums
y: (C,R) # Outputs

The system performs:
y(C,R) = k.T(C,K) @ x(K,R) + a(C,R)
```

![Full System](docs/sys.png)

## Key files

* `run/golden.py` - Python reference that performs `y = k.T @ x + a`
* `run/sources.txt` - List of source files needed for simulation
* `tb/top_tb.sv` - Top testbench
* `rtl/sys/top.v` - Top RTL module with 4 M_AXI & one S_AXIL ports.
* `c/firmware.h` - Contains the basic firmware
* `rtl/sys/dma_controller.sv` - DMA controller that corresponds with firmware
* `rtl/sa/axis_sa.sv` - AXI Stream Systolic array

## To simulate the entire system:

### Verilator (Linux)

Add Verilator path (eg. `/tools/verilator/bin`) to `$PATH`
```
make veri
```

### Vivado Xsim (Linux)

Add Vivado path (eg. `/tools/Xilinx/Vivado/2022.2/bin`) to `$PATH`
```
make xsim
```

### Vivado Xsim (Windows)

First update `XIL_PATH` in `run/xsim.bat`, then run these in powershell
```
cd run
./xsim.bat
```

### Test on Xilinx ZCU104

#### Vivado: 

1. Create block diagram, add ZYNQ, run block automation, configure it to enable 3 AXI slaves and 1 AXI master.
1. Add all files in `rtl` to design
1. Drag and drop `top.v` to block diagram
1. Double click on `top.v`, edit the parameters to match `run/build/params.h`
1. Connect the 3 MM2S ports to the AXI slaves.
1. Run automation to connect the AXI Lite slave to the ZYNQ.
1. Edit the address map such that the address of AXI-Lite slave is same as CONFIG_BASEADDR in `run/build/params.h`
1. Ensure address ranges of AXI slaves contain `MEM_BASEADDR + sizeof(all data)`. 
1. Generate HDL wrapper for block design, set as top.
1. Validate design, generate bitstream, export hardware.

#### Vitis:

1. Launch SDK, create a new application project, select `Custom XSA` and select the exported hardware.
1. Choose Hello World template.
1. Copy and paste the contents of `c/xilinx_example.c` to `helloworld.c`
1. Right click on project, `C/C++ build settings`, select `Directories` and add `c/` and `run/work/data/` to the include path.
1. Build the project.
1. Connect the ZCU104 to the host machine, turn it on.
1. Right click on the project, `Run As`, `Debug: Launch on Hardware (Single Application Debug)`
1. Open Vitis serial console and connect to the correct COM port.
1. Click `Resume` to run the program.

## Resources & Performance

Following was done on ZCU104. 
```
R=32,
C=32,
AXI_WIDTH=128
WK=8
WX=8
WA=32
WY=32
FREQ=100MHz
```

![FPGA](docs/fpga.png)
