# AXIS VHDL Library

A library of reusable AXI-Stream (AXIS) components written in VHDL-2008.

## Modules

| Module | File | Description |
|--------|------|-------------|
| Buffer | `src/axis_buffer.vhd` | Single-stage skid buffer / pipeline register |
| FIFO | `src/axis_fifo.vhd` | Synchronous FIFO with configurable depth |
| Drop-Packet FIFO | `src/axis_fifo_dp.vhd` | FIFO with speculative write and packet rollback |
| Data Width Converter | `src/axis_dwidth_conv.vhd` | Upsize or downsize data width (N:1 or 1:N) |
| Error Injection | `src/axis_error_inj.vhd` | Injects bit-flips, drops, duplicates, etc. |
| Frame Length Checker | `src/axis_frame_len.vhd` | Validates frame size against min/max limits |
| MUX | `src/axis_mux.vhd` | N-to-1 multiplexer with round-robin or fixed priority |
| DeMUX | `src/axis_demux.vhd` | 1-to-N demultiplexer routed by tdest |
| Joiner | `src/axis_joiner.vhd` | Combines N independent input streams into one |
| Splitter | `src/axis_splitter.vhd` | Splits header beats from payload beats |
| Broadcaster | `src/axis_broadcaster.vhd` | Replicates one input to N outputs |

---

## AXI-Stream Interface

Each module uses the standard AXI-Stream signals:

| Signal | Direction | Description |
|--------|-----------|-------------|
| `aclk` | Input | Clock |
| `aresetn` | Input | Synchronous active-low reset |
| `tvalid` | Master→Slave | Data valid |
| `tready` | Slave→Master | Slave ready (backpressure) |
| `tdata` | Master→Slave | Data payload |
| `tkeep` | Master→Slave | Byte-enable (one bit per data byte) |
| `tlast` | Master→Slave | End of packet marker |
| `tuser` | Master→Slave | Sideband user bits |
| `tid` | Master→Slave | Stream identifier |
| `tdest` | Master→Slave | Routing destination |

---

## Module Details

### axis_buffer

A single-register pipeline stage (skid buffer) that decouples master and slave
backpressure domains without dropping data.

```vhdl
entity axis_buffer is
    generic (
        DATA_WIDTH  : positive := 8;
        KEEP_ENABLE : natural  := 1;
        LAST_ENABLE : natural  := 1;
        USER_WIDTH  : natural  := 1;
        ID_WIDTH    : natural  := 1;
        DEST_WIDTH  : natural  := 1
    );
```

---

### axis_fifo

Synchronous FIFO with a RAM-based circular buffer.

```vhdl
entity axis_fifo is
    generic (
        DATA_WIDTH  : positive := 8;
        DEPTH       : positive := 16;  -- must be power of 2
        ...
    );
    port (
        ...
        full  : out std_logic;
        empty : out std_logic;
        level : out std_logic_vector(clog2(DEPTH+1)-1 downto 0);
        ...
    );
```

---

### axis_fifo_dp (Drop-Packet FIFO)

Extends `axis_fifo` with speculative write support.  Incoming packets are
written speculatively.  The `drop_i` signal rolls back the write pointer to
the last committed position, discarding the partial/erroneous packet.
`commit_i` (or `AUTO_COMMIT=1`) makes the speculative data visible to the
reader.

```vhdl
generic (
    AUTO_COMMIT : natural := 1  -- auto-commit on tlast when drop_i='0'
);
port (
    commit_i : in std_logic := '0';
    drop_i   : in std_logic := '0';
    ...
);
```

---

### axis_dwidth_conv

Converts between different data widths.

- **Upsizing** (`S_DATA_WIDTH < M_DATA_WIDTH`): accumulates narrow beats into
  a single wide beat. The ratio must divide evenly.
- **Downsizing** (`S_DATA_WIDTH > M_DATA_WIDTH`): splits a wide beat into
  multiple narrow beats.
- **Pass-through** when widths are equal.

```vhdl
generic (
    S_DATA_WIDTH : positive := 8;   -- Input data width
    M_DATA_WIDTH : positive := 32;  -- Output data width
    ...
);
```

---

### axis_error_inj

Arms a single error injection on `err_inject_i` pulse. The error is applied
to subsequent data:

| `err_type_i` | Effect |
|---|---|
| `000` | No error (pass-through) |
| `001` | Bit-flip: XOR `err_mask_i` into tdata |
| `010` | Drop: swallow the entire packet |
| `011` | Duplicate: (arm a duplicate send) |
| `100` | Early-last: force tlast on specified beat |
| `101` | Keep corrupt: zero out tkeep |

---

### axis_frame_len

Transparent pass-through that counts bytes per packet using `tkeep` and
asserts error flags on the `tlast` cycle:

```vhdl
generic (
    MIN_FRAME_BYTES : natural  := 64;
    MAX_FRAME_BYTES : natural  := 1518;
    LEN_BITS        : positive := 16
);
port (
    frame_len_o : out std_logic_vector(LEN_BITS-1 downto 0);
    err_short_o : out std_logic;   -- frame < MIN_FRAME_BYTES
    err_long_o  : out std_logic    -- frame > MAX_FRAME_BYTES
);
```

---

### axis_mux

N-to-1 multiplexer.  Arbitration is packet-granular (the whole packet from
a chosen port is forwarded before switching).

```vhdl
generic (
    N_PORTS  : positive := 2;
    ARB_TYPE : natural  := 1  -- 0=fixed-priority, 1=round-robin
);
```

Ports are provided as flat vectors: port *k* occupies
`[(k+1)*DATA_WIDTH-1 : k*DATA_WIDTH]`.

---

### axis_demux

1-to-N demultiplexer.  The destination is latched at the first beat of each
packet and held for the whole packet.

```vhdl
generic (
    N_PORTS   : positive := 2;
    USE_TDEST : natural  := 1  -- 1 = route by tdest, 0 = use external select_i
);
port (
    select_i : in std_logic_vector(clog2(N_PORTS)-1 downto 0) := (others => '0');
    ...
);
```

---

### axis_joiner

Synchronises N input streams into one combined output.  All inputs must assert
`tvalid` before any beat is consumed.  `tlast` is asserted only when ALL
inputs assert `tlast`.

```vhdl
generic (
    N_PORTS    : positive := 2;
    DATA_WIDTH : positive := 8   -- per-port width; output is N*DATA_WIDTH wide
);
```

---

### axis_splitter

Routes the first `SPLIT_BEAT` beats of each packet to output **A** (header)
and the remaining beats to output **B** (payload).

```vhdl
generic (
    SPLIT_BEAT : natural := 1  -- number of beats sent to output A
);
```

---

### axis_broadcaster

Replicates one input stream to all N outputs.  A beat is only consumed when
all outputs have accepted it.  Ports that are already ready are tracked
internally so only the slowest port stalls the pipeline.

```vhdl
generic (
    N_PORTS : positive := 2
);
```

---

## Directory Structure

```
axis_lib/
├── Makefile          – Build / simulation automation (GHDL + CocoTB)
├── Makefile.cocotb   – CocoTB simulation runner (all modules)
├── README.md         – This file
├── src/              – Synthesisable source files
│   ├── axis_pkg.vhd
│   ├── axis_buffer.vhd
│   ├── axis_fifo.vhd
│   ├── axis_fifo_dp.vhd
│   ├── axis_dwidth_conv.vhd
│   ├── axis_error_inj.vhd
│   ├── axis_frame_len.vhd
│   ├── axis_mux.vhd
│   ├── axis_demux.vhd
│   ├── axis_joiner.vhd
│   ├── axis_splitter.vhd
│   └── axis_broadcaster.vhd
└── tb/               – Testbenches (VHDL + CocoTB Python)
    ├── tb_axis_buffer.vhd              – VHDL testbench
    ├── tb_axis_fifo.vhd
    ├── tb_axis_fifo_dp.vhd
    ├── tb_axis_dwidth_conv.vhd
    ├── tb_axis_mux_demux.vhd
    ├── tb_axis_broadcaster.vhd
    ├── tb_axis_frame_len.vhd
    ├── tb_axis_joiner_splitter.vhd
    ├── axis_buffer_cocotb_tb.vhd       – CocoTB VHDL wrapper
    ├── axis_fifo_cocotb_tb.vhd
    ├── axis_fifo_dp_cocotb_tb.vhd
    ├── axis_dwidth_conv_cocotb_tb.vhd
    ├── axis_frame_len_cocotb_tb.vhd
    ├── axis_mux_demux_cocotb_tb.vhd
    ├── axis_broadcaster_cocotb_tb.vhd
    ├── axis_joiner_splitter_cocotb_tb.vhd
    ├── test_axis_buffer.py             – CocoTB Python test
    ├── test_axis_fifo.py
    ├── test_axis_fifo_dp.py
    ├── test_axis_dwidth_conv.py
    ├── test_axis_frame_len.py
    ├── test_axis_mux_demux.py
    ├── test_axis_broadcaster.py
    └── test_axis_joiner_splitter.py
```

## Building and Simulating

Requirements: [GHDL](https://github.com/ghdl/ghdl) 2.0 or later.

```bash
# Compile sources and run all VHDL testbenches
make

# Compile only
make compile

# Clean build artifacts
make clean
```

All testbenches report `ALL TESTS PASSED` on success and call
`report ... severity failure` on any mismatch.

## CocoTB Simulation

Requires GHDL 2.0 or later and [CocoTB](https://www.cocotb.org/) 2.0 or later.

```bash
# Run all CocoTB simulations (generates waveforms in sim/cocotb_build/)
make sim-cocotb

# Run a specific module only
make -f Makefile.cocotb sim-axis_buffer

# Available module targets:
#   sim-axis_buffer, sim-axis_fifo, sim-axis_fifo_dp,
#   sim-axis_dwidth_conv, sim-axis_frame_len, sim-axis_mux_demux,
#   sim-axis_broadcaster, sim-axis_joiner_splitter

# Clean CocoTB build artefacts
make -f Makefile.cocotb clean
```

Each simulation writes waveforms to:
- `sim/cocotb_build/<module>/<module>_cocotb_tb.vcd` – Value Change Dump (GTKWave, etc.)
- `sim/cocotb_build/<module>/<module>_cocotb_tb.ghw` – GHW native GHDL format

```bash
# Open a waveform (example)
gtkwave sim/cocotb_build/axis_buffer/axis_buffer_cocotb_tb.vcd
```

## VHDL Standard

All files target **VHDL-2008** (`--std=08`).
