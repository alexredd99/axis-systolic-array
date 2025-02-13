iverilog:
	mkdir -p build
	iverilog -g2012 -o build/compiled tb/* rtl/*
	vvp build/compiled

verilator:
	mkdir -p build
	verilator --binary -j 0 -O3 --trace --top axis_matvec_mul_tb -Mdir build/ rtl/* tb/*
	./build/Vaxis_matvec_mul_tb