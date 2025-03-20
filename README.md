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
