"""CocoTB test suite for axis_buffer (skid buffer / pipeline register).

Tests:
  1. Simple pass-through: data flows through with m_ready always high.
  2. Back-pressure: data is held when m_ready is low, then released correctly.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_dut(dut, cycles=3):
    """Apply active-low reset for *cycles* clock edges."""
    dut.aresetn.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tkeep.value = 1
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def send_beat(dut, data, last=0):
    """Send one beat and wait for it to be accepted (s_ready=1)."""
    dut.s_axis_tdata.value = data
    dut.s_axis_tlast.value = last
    dut.s_axis_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0


async def recv_beat(dut):
    """Wait for a valid beat on the master side and return (data, last)."""
    dut.m_axis_tready.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.m_axis_tvalid.value) == 1:
            return int(dut.m_axis_tdata.value), int(dut.m_axis_tlast.value)


@cocotb.test()
async def test_pass_through(dut):
    """Pass-through: send two beats with m_ready always high."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.m_axis_tready.value = 1

    await send_beat(dut, 0xAA, last=0)
    await Timer(10, unit="ns")
    await send_beat(dut, 0xBB, last=1)
    await Timer(30, unit="ns")

    dut._log.info("PASS test_pass_through")


@cocotb.test()
async def test_back_pressure(dut):
    """Back-pressure: hold m_ready low, then release and verify data."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    # Hold downstream not ready, present beat 0xCC
    dut.m_axis_tready.value = 0
    dut.s_axis_tdata.value = 0xCC
    dut.s_axis_tlast.value = 0
    dut.s_axis_tvalid.value = 1
    await Timer(20, unit="ns")

    # Release downstream and wait for the beat to appear
    dut.m_axis_tready.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tready.value) == 1:
            data = int(dut.m_axis_tdata.value)
            assert data == 0xCC, f"Back-pressure data mismatch: expected 0xCC, got 0x{data:02X}"
            break
    dut.s_axis_tvalid.value = 0
    await Timer(50, unit="ns")

    dut._log.info("PASS test_back_pressure")
