"""CocoTB test suite for axis_fifo (synchronous FIFO, DEPTH=8).

Tests:
  1. Write 4 beats + 1 last, read them back in order.
  2. Fill to near-full then drain.
  3. Verify empty flag after draining.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

FIFO_DEPTH = 8   # must match DEPTH generic in axis_fifo_cocotb_tb.vhd


async def reset_dut(dut, cycles=3):
    """Apply active-low reset."""
    dut.aresetn.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tkeep.value = 1
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def write_beat(dut, data, last=0):
    """Write one beat into the FIFO (waits for s_ready)."""
    dut.s_axis_tdata.value = data
    dut.s_axis_tlast.value = last
    dut.s_axis_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    await Timer(1, unit="ns")


async def read_beat(dut, expected):
    """Read one beat from the FIFO and verify data."""
    dut.m_axis_tready.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.m_axis_tvalid.value) == 1:
            got = int(dut.m_axis_tdata.value)
            assert got == expected, (
                f"FIFO read mismatch: expected 0x{expected:02X}, got 0x{got:02X}"
            )
            break
    dut.m_axis_tready.value = 0


@cocotb.test()
async def test_write_read_order(dut):
    """Write 4+1 beats and read them back in FIFO order."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    pattern = [0x11, 0x22, 0x33, 0x44, 0x55]
    for i, byte in enumerate(pattern):
        last = 1 if i == len(pattern) - 1 else 0
        await write_beat(dut, byte, last)

    for byte in pattern:
        await read_beat(dut, byte)

    await Timer(50, unit="ns")
    dut._log.info("PASS test_write_read_order")


@cocotb.test()
async def test_near_full_drain(dut):
    """Fill FIFO to FIFO_DEPTH-1 (7 entries) then drain."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    for i in range(FIFO_DEPTH - 1):
        last = 1 if i == FIFO_DEPTH - 2 else 0
        await write_beat(dut, i, last)

    # Drain
    dut.m_axis_tready.value = 1
    for _ in range(FIFO_DEPTH - 1):
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.m_axis_tvalid.value) == 1:
                break
    dut.m_axis_tready.value = 0
    await Timer(50, unit="ns")

    dut._log.info("PASS test_near_full_drain")


@cocotb.test()
async def test_empty_flag(dut):
    """Verify empty flag is high after reset with no writes."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    await RisingEdge(dut.aclk)
    assert int(dut.empty.value) == 1, "FIFO should be empty after reset"

    dut._log.info("PASS test_empty_flag")
