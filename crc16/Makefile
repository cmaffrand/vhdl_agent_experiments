GHDL      = ghdl
GTKWAVE   = gtkwave
STD       = --std=08
WORKDIR   = --workdir=sim/work
WORK      = --work=work
GHDL_ANA  = $(GHDL) -a $(STD) $(WORK) $(WORKDIR)
GHDL_ELB  = $(GHDL) -e $(STD) $(WORK) $(WORKDIR)
GHDL_RUN  = $(GHDL) -r $(STD) $(WORK) $(WORKDIR)

TOP       = crc16_tb
WAVE      = sim/$(TOP).ghw
SAVEFILE  = tb/$(TOP).gtkw

SRCS = src/crc16_pkg.vhd \
       src/crc16.vhd

TBS  = tb/crc16_tb.vhd

.PHONY: all sim wave clean

all: sim

sim/work:
	mkdir -p sim/work

analyze: sim/work
	$(GHDL_ANA) $(SRCS) $(TBS)

sim: analyze
	$(GHDL_ELB) $(TOP)
	$(GHDL_RUN) $(TOP) --wave=$(WAVE)

wave: sim
	$(GTKWAVE) $(WAVE) $(SAVEFILE)

clean:
	rm -rf sim/
