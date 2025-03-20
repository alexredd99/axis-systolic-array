# Define variables
R = 8
C = 4
K = 16

TB_MODULE = top_tb
BUILD_DIR = run/build
DATA_DIR = $(BUILD_DIR)/data
FULL_DATA_DIR = $(abspath $(DATA_DIR))
C_SOURCE = ../../c/sim.c
SOURCES_FILE = sources.txt
XSIM_CFG = ../xsim_cfg.tcl

# Compiler options
XSC_FLAGS = --gcc_compile_options -DSIM --gcc_compile_options -DDIR=$(FULL_DATA_DIR) --gcc_compile_options -I$(FULL_DATA_DIR)
XVLOG_FLAGS = -sv -d "DIR=$(FULL_DATA_DIR)" 
XELAB_FLAGS = --snapshot $(TB_MODULE) -log elaborate.log --debug typical -sv_lib dpi
XSIM_FLAGS = --tclbatch $(XSIM_CFG)
VERI_FLAGS = --binary -j 0 -O3 -DDIR=$(FULL_DATA_DIR) -CFLAGS -DSIM -CFLAGS -DDIR=$(FULL_DATA_DIR) -CFLAGS -g --Mdir ../$(BUILD_DIR) -CFLAGS -I$(FULL_DATA_DIR)/ --Wno-BLKANDNBLK --Wno-INITIALDLY

# Ensure the build directories exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(DATA_DIR): | $(BUILD_DIR)
	mkdir -p $(DATA_DIR)

# Golden model
$(DATA_DIR)/kxa.bin: $(DATA_DIR)
	python run/golden.py --R $(R) --K $(K) --C $(C) --DIR $(FULL_DATA_DIR)

# Compile C source
c: $(BUILD_DIR) $(DATA_DIR)/kxa.bin
	cd $(BUILD_DIR) && xsc $(C_SOURCE) $(XSC_FLAGS)

# Run Verilog compilation
vlog: c
	cd $(BUILD_DIR) && xvlog -f ../$(SOURCES_FILE)  $(XVLOG_FLAGS)

# Elaborate design
elab: vlog
	cd $(BUILD_DIR) && xelab $(TB_MODULE) $(XELAB_FLAGS)

# Run simulation
xsim: elab $(DATA_DIR)
	cd $(BUILD_DIR) && xsim $(TB_MODULE) $(XSIM_FLAGS)

build_verilator: $(BUILD_DIR) $(DATA_DIR)/kxa.bin
	cd run && verilator --top $(TB_MODULE) -F $(SOURCES_FILE) $(C_SOURCE) $(VERI_FLAGS)

veri: build_verilator $(DATA_DIR)
	cd $(BUILD_DIR) && ./V$(TB_MODULE)


veri_axis: rtl/axis_sa.sv rtl/mac.sv rtl/n_delay.sv rtl/tri_buffer.sv tb/axis_sa_tb.sv tb/axis_vip/tb/axis_sink.sv tb/axis_vip/tb/axis_source.sv
	mkdir -p run/build
	verilator --binary -j 0 -O3 --trace --top axis_sa_tb -Mdir run/build/ $^ --Wno-BLKANDNBLK --Wno-INITIALDLY
	@cd run && build/Vaxis_sa_tb

# Clean build directory
clean:
	rm -rf $(BUILD_DIR)

.PHONY: sim vlog elab run clean
