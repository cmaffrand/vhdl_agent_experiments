# ---------------------------------------------------------------------------
# Available targets
#   sim-vhdl    — standalone GHDL simulation (original VHDL testbench)
#   sim-cocotb  — CocoTB simulation using GHDL as the backend
#   all         — run both simulations
#   wave        — open waveform from the last sim-vhdl run (requires GTKWave)
#   wave-cocotb — open waveform from the last sim-cocotb run (requires GTKWave)
#   clean       — remove all simulation artefacts
# ---------------------------------------------------------------------------
.PHONY: all sim-vhdl sim-cocotb analyze-vhdl wave wave-cocotb clean

all: sim-vhdl sim-cocotb

# ---------------------------------------------------------------------------
# VHDL standalone simulation (GHDL)
# ---------------------------------------------------------------------------
GHDL     = ghdl
GTKWAVE  = gtkwave

VHDL_TOP = crc16_tb
WAVE     = sim/$(VHDL_TOP).ghw
VCD      = sim/$(VHDL_TOP).vcd
SAVEFILE = tb/$(VHDL_TOP).gtkw

SRCS = src/crc16_pkg.vhd \
       src/crc16.vhd

TBS  = tb/crc16_tb.vhd

sim/work:
	mkdir -p sim/work

analyze-vhdl: sim/work
	$(GHDL) -a --std=08 --work=work --workdir=sim/work $(SRCS) $(TBS)

sim-vhdl: analyze-vhdl
	$(GHDL) -e --std=08 --work=work --workdir=sim/work $(VHDL_TOP)
	$(GHDL) -r --std=08 --work=work --workdir=sim/work $(VHDL_TOP) --wave=$(WAVE) --vcd=$(VCD)

wave: sim-vhdl
	$(GTKWAVE) $(VCD) $(SAVEFILE)

# ---------------------------------------------------------------------------
# CocoTB simulation (GHDL backend)
# ---------------------------------------------------------------------------
COCOTB_TOP     = crc16_cocotb_tb
COCOTB_VCD     = sim/cocotb_build/$(COCOTB_TOP).vcd
COCOTB_SAVEFILE = tb/$(COCOTB_TOP).gtkw

sim-cocotb:
	$(MAKE) -f Makefile.cocotb

wave-cocotb: sim-cocotb
	$(GTKWAVE) $(COCOTB_VCD) $(if $(wildcard $(COCOTB_SAVEFILE)),$(COCOTB_SAVEFILE),)

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
clean:
	rm -rf sim/
	$(MAKE) -f Makefile.cocotb clean
