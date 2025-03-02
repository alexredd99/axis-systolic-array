verilator:
	mkdir -p build
	verilator --binary -j 0 -O3 --trace --top axis_sa_tb -Mdir build/ rtl/* tb/* --Wno-BLKANDNBLK
	mkdir -p run
	@cd run && ../build/Vaxis_sa_tb

axis_tb_nofile: tb/axis2_tb.sv
	mkdir -p build
	verilator --binary -j 0 -O3 --trace --top axis_tb -Mdir build/ $^ --Wno-INITIALDLY
	mkdir -p run
	@cd run && ../build/Vaxis_tb

axis_tb_file: tb/axis2_tb.sv
	mkdir -p build
	verilator --binary -j 0 -O3 --trace --top axis_tb -Mdir build/ $^ --Wno-INITIALDLY -DFILE_TEST
	mkdir -p run
	@cd run && ../build/Vaxis_tb

clean:
	rm -rf build run

all: verilator axis_tb_nofile axis_tb_file