# =============================================================================
# Makefile for the axis_crc16 modules
# Depends on the crc16 library (../crc16/src/) for CRC16 primitives.
#
# Available targets:
#   sim-cocotb  — run all CocoTB simulations (default)
#   clean       — remove all simulation artefacts
# =============================================================================

.PHONY: all sim-cocotb clean

all: sim-cocotb

sim-cocotb:
	$(MAKE) -f Makefile.cocotb

clean:
	rm -rf sim/
	$(MAKE) -f Makefile.cocotb clean
