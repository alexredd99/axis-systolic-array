# sv2v integer_axis_sa_tb.sv --top integer_axis_sa_tb -w tb.v
# iverilog -o testbench tb.v

# Makefile for compiling SystemVerilog testbench via sv2v and iverilog

# TOP      := integer_axis_sa_tb
TOP 		 ?= integer_axis_sa_tb
SV_FILE  := $(TOP).sv
VERILOG  := tb.v
BIN      := testbench
VCD      := dump.vcd

.PHONY: all clean run

all: $(BIN)

$(VERILOG): $(SV_FILE)
	sv2v $(SV_FILE) --top $(TOP) -w $(VERILOG)

$(BIN): $(VERILOG)
	iverilog -o $(BIN) $(VERILOG)


run: $(BIN)
	vvp $(BIN)

clean:
	rm -f $(VERILOG) $(BIN) $(VCD)
