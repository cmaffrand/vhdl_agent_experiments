"""CocoTB test suite for axis_dwidth_conv.

Two DUT instances share the clock/reset:
  - Upsizer  (8-bit in  -> 32-bit out): ports prefixed up_
  - Downsizer (32-bit in ->  8-bit out): ports prefixed dn_

Tests:
  1. Upsize: send 4 bytes 0x01..0x04 with last on byte 4 -> expect 0x04030201 out.
  2. Downsize: send 0xDEADBEEF (last=1) -> expect 4 bytes EF BE AD DE (little-endian).
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_dut(dut, cycles=3):
    """Apply active-low reset, idle all ports."""
    dut.aresetn.value = 0
    dut.up_s_tvalid.value = 0
    dut.up_s_tdata.value = 0
    dut.up_s_tkeep.value = 1
    dut.up_s_tlast.value = 0
    dut.up_m_tready.value = 1
    dut.dn_s_tvalid.value = 0
    dut.dn_s_tdata.value = 0
    dut.dn_s_tkeep.value = 0xF
    dut.dn_s_tlast.value = 0
    dut.dn_m_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def up_send_beat(dut, data, last=0):
    """Send one narrow (8-bit) beat to the upsizer."""
    dut.up_s_tdata.value = data
    dut.up_s_tlast.value = last
    dut.up_s_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.up_s_tready.value) == 1:
            break
    dut.up_s_tvalid.value = 0
    await Timer(1, unit="ns")


async def dn_send_beat(dut, data, last=0):
    """Send one wide (32-bit) beat to the downsizer."""
    dut.dn_s_tdata.value = data
    dut.dn_s_tlast.value = last
    dut.dn_s_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.dn_s_tready.value) == 1:
            break
    dut.dn_s_tvalid.value = 0
    await Timer(1, unit="ns")


@cocotb.test()
async def test_upsize(dut):
    """Upsize 4x8-bit bytes to one 32-bit word; expect little-endian packing."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.up_m_tready.value = 1

    await up_send_beat(dut, 0x01, last=0)
    await up_send_beat(dut, 0x02, last=0)
    await up_send_beat(dut, 0x03, last=0)
    await up_send_beat(dut, 0x04, last=1)

    # Wait for the wide output beat
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.up_m_tvalid.value) == 1:
            got = int(dut.up_m_tdata.value)
            assert got == 0x04030201, (
                f"Upsize mismatch: expected 0x04030201, got 0x{got:08X}"
            )
            assert int(dut.up_m_tlast.value) == 1, "Upsize: tlast should be 1"
            break

    await Timer(30, unit="ns")
    dut._log.info("PASS test_upsize")


@cocotb.test()
async def test_downsize(dut):
    """Downsize 0xDEADBEEF to 4 bytes in little-endian order: EF BE AD DE."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.dn_m_tready.value = 1
    await dn_send_beat(dut, 0xDEADBEEF, last=1)

    expected = [0xEF, 0xBE, 0xAD, 0xDE]
    for i, exp in enumerate(expected):
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.dn_m_tvalid.value) == 1:
                got = int(dut.dn_m_tdata.value)
                assert got == exp, (
                    f"Downsize byte {i} mismatch: expected 0x{exp:02X}, got 0x{got:02X}"
                )
                break

    assert int(dut.dn_m_tlast.value) == 1, "Downsize: tlast should be 1 on last byte"
    await Timer(30, unit="ns")
    dut._log.info("PASS test_downsize")
