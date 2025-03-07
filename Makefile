verilator: rtl/axis_sa.sv rtl/mac.sv rtl/n_delay.sv rtl/tri_buffer.sv tb/axis_sa_tb.sv tb/axis_vip/tb/axis_sink.sv tb/axis_vip/tb/axis_source.sv
	mkdir -p run/build
	verilator --binary -j 0 -O3 --trace --top axis_sa_tb -Mdir run/build/ $^ --Wno-BLKANDNBLK --Wno-INITIALDLY
	@cd run && build/Vaxis_sa_tb

clean:
	rm -rf run

all: verilator