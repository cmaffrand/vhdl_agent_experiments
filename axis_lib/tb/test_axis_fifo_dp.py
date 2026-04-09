"""CocoTB test suite for axis_fifo_dp (drop-packet FIFO, DEPTH=32, AUTO_COMMIT=1).

Tests:
  1. Auto-commit: write a 3-beat packet (tlast auto-commits), read back.
  2. Drop: write a packet with drop_i asserted on tlast – data must NOT appear.
  3. Write a valid packet after drop and verify it can be read.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_dut(dut, cycles=3):
    """Apply active-low reset."""
    dut.aresetn.value = 0
    dut.commit_i.value = 0
    dut.drop_i.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tkeep.value = 1
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def write_beat(dut, data, last=0, drop=0):
    """Write one beat, optionally with drop_i asserted."""
    dut.s_axis_tdata.value = data
    dut.s_axis_tlast.value = last
    dut.drop_i.value = drop
    dut.s_axis_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    dut.drop_i.value = 0
    await Timer(1, unit="ns")


async def read_beat(dut, expected):
    """Read one beat and verify against expected."""
    dut.m_axis_tready.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.m_axis_tvalid.value) == 1:
            got = int(dut.m_axis_tdata.value)
            assert got == expected, (
                f"DP-FIFO read mismatch: expected 0x{expected:02X}, got 0x{got:02X}"
            )
            break
    dut.m_axis_tready.value = 0


@cocotb.test()
async def test_auto_commit(dut):
    """Auto-commit on tlast: write AA BB CC (last), read back all three."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    await write_beat(dut, 0xAA, last=0)
    await write_beat(dut, 0xBB, last=0)
    await write_beat(dut, 0xCC, last=1)
    await Timer(20, unit="ns")

    await read_beat(dut, 0xAA)
    await read_beat(dut, 0xBB)
    await read_beat(dut, 0xCC)
    await Timer(50, unit="ns")

    dut._log.info("PASS test_auto_commit")


@cocotb.test()
async def test_drop_packet(dut):
    """Drop a 3-beat packet: FIFO must be empty afterwards."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    await write_beat(dut, 0x11, last=0)
    await write_beat(dut, 0x22, last=0)
    await write_beat(dut, 0x33, last=1, drop=1)  # drop on tlast
    await Timer(30, unit="ns")

    assert int(dut.empty.value) == 1, "FIFO should be empty after drop"

    dut._log.info("PASS test_drop_packet")


@cocotb.test()
async def test_valid_after_drop(dut):
    """Write a valid packet after a dropped one and verify readback."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    # Drop a packet
    await write_beat(dut, 0xBA, last=0)
    await write_beat(dut, 0xD0, last=1, drop=1)
    await Timer(20, unit="ns")

    # Now write a valid packet
    await write_beat(dut, 0xDE, last=0)
    await write_beat(dut, 0xAD, last=1)
    await Timer(20, unit="ns")

    await read_beat(dut, 0xDE)
    await read_beat(dut, 0xAD)
    await Timer(50, unit="ns")

    dut._log.info("PASS test_valid_after_drop")
