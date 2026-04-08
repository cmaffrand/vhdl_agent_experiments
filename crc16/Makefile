# ---------------------------------------------------------------------------
# CocoTB simulation (default target)
# ---------------------------------------------------------------------------
SIM              ?= ghdl
TOPLEVEL_LANG     = vhdl

VHDL_SOURCES      = $(PWD)/src/crc16_pkg.vhd \
                    $(PWD)/src/crc16.vhd \
                    $(PWD)/tb/crc16_cocotb_tb.vhd

COCOTB_TOPLEVEL        = crc16_cocotb_tb
COCOTB_TEST_MODULES    = test_crc16

COMPILE_ARGS      = --std=08
GHDL_ARGS         = --std=08

SIM_BUILD         = sim/cocotb_build

export PYTHONPATH := $(PWD)/tb:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim

# ---------------------------------------------------------------------------
# Legacy GHDL-only targets (kept for waveform viewing)
# ---------------------------------------------------------------------------
GTKWAVE   = gtkwave
WORKDIR   = --workdir=sim/work
WORK      = --work=work
GHDL_ANA  = ghdl -a --std=08 $(WORK) $(WORKDIR)
GHDL_ELB  = ghdl -e --std=08 $(WORK) $(WORKDIR)
GHDL_RUN  = ghdl -r --std=08 $(WORK) $(WORKDIR)

VHDL_TOP  = crc16_tb
WAVE      = sim/$(VHDL_TOP).ghw
VCD       = sim/$(VHDL_TOP).vcd
SAVEFILE  = tb/$(VHDL_TOP).gtkw

SRCS = src/crc16_pkg.vhd \
       src/crc16.vhd

TBS  = tb/crc16_tb.vhd

sim/work:
	mkdir -p sim/work

analyze-vhdl: sim/work
	$(GHDL_ANA) $(SRCS) $(TBS)

sim-vhdl: analyze-vhdl
	$(GHDL_ELB) $(VHDL_TOP)
	$(GHDL_RUN) $(VHDL_TOP) --wave=$(WAVE) --vcd=$(VCD)

wave: sim-vhdl
	$(GTKWAVE) $(VCD) $(SAVEFILE)

clean::
	rm -rf sim/work sim/*.ghw sim/*.vcd
