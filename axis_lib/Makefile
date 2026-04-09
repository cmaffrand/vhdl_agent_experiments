# =============================================================================
# Makefile for the AXIS VHDL Library
# Uses GHDL for compilation and simulation.
# =============================================================================

GHDL       ?= ghdl
STD        := 08
WORKDIR    := sim/work
WORK       := work

GHDL_FLAGS := --std=$(STD) --work=$(WORK) --workdir=$(WORKDIR)

# Source files in dependency order
SRC_FILES := \
	src/axis_pkg.vhd \
	src/axis_buffer.vhd \
	src/axis_fifo.vhd \
	src/axis_fifo_dp.vhd \
	src/axis_dwidth_conv.vhd \
	src/axis_error_inj.vhd \
	src/axis_frame_len.vhd \
	src/axis_mux.vhd \
	src/axis_demux.vhd \
	src/axis_joiner.vhd \
	src/axis_splitter.vhd \
	src/axis_broadcaster.vhd

# Testbench files
TB_FILES := \
	tb/tb_axis_buffer.vhd \
	tb/tb_axis_fifo.vhd \
	tb/tb_axis_fifo_dp.vhd \
	tb/tb_axis_dwidth_conv.vhd \
	tb/tb_axis_mux_demux.vhd \
	tb/tb_axis_broadcaster.vhd \
	tb/tb_axis_frame_len.vhd \
	tb/tb_axis_joiner_splitter.vhd

# Testbench top-level entities
TB_TOPS := \
	tb_axis_buffer \
	tb_axis_fifo \
	tb_axis_fifo_dp \
	tb_axis_dwidth_conv \
	tb_axis_mux_demux \
	tb_axis_broadcaster \
	tb_axis_frame_len \
	tb_axis_joiner_splitter

SIM_TIME   := 20us

GTKWAVE    ?= gtkwave

.PHONY: all compile compile-tb sim sim-cocotb wave-cocotb clean

all: sim

$(WORKDIR):
	mkdir -p $(WORKDIR)

compile: $(WORKDIR)
	@echo "=== Compiling source files ==="
	@for f in $(SRC_FILES); do \
		echo "  $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) $$f || exit 1; \
	done

compile-tb: compile
	@echo "=== Compiling testbenches ==="
	@for f in $(TB_FILES); do \
		echo "  $$f"; \
		$(GHDL) -a $(GHDL_FLAGS) $$f || exit 1; \
	done

sim: compile-tb
	@echo "=== Running simulations ==="
	@PASS=0; FAIL=0; \
	for tb in $(TB_TOPS); do \
		$(GHDL) -e $(GHDL_FLAGS) $$tb; \
		OUTPUT=$$($(GHDL) -r $(GHDL_FLAGS) $$tb --stop-time=$(SIM_TIME) 2>&1); \
		echo "$$OUTPUT"; \
		if echo "$$OUTPUT" | grep -q "ERRORS\|failed\|error"; then \
			echo "FAILED: $$tb"; FAIL=$$((FAIL+1)); \
		else \
			echo "PASSED: $$tb"; PASS=$$((PASS+1)); \
		fi; \
	done; \
	echo ""; \
	echo "=== SUMMARY: $$PASS passed, $$FAIL failed ==="; \
	test $$FAIL -eq 0

sim-cocotb:
	$(MAKE) -f Makefile.cocotb

wave-cocotb:
	@echo "Waveforms are in sim/cocotb_build/<module>/<module>_cocotb_tb.{vcd,ghw}"
	@echo "Example: $(GTKWAVE) sim/cocotb_build/axis_buffer/axis_buffer_cocotb_tb.vcd"

clean:
	rm -rf $(WORKDIR) *.cf sim/*.cf
	$(MAKE) -f Makefile.cocotb clean
