verilator:
	mkdir -p build
	verilator --binary -j 0 -O3 --trace --top axis_sa_tb -Mdir build/ rtl/* tb/* --Wno-BLKANDNBLK
	mkdir -p run
	@cd run && ../build/Vaxis_sa_tb