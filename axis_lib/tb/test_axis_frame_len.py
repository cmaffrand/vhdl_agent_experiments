"""CocoTB test suite for axis_frame_len (frame-length checker).

DUT: axis_frame_len with DATA_WIDTH=8, MIN_FRAME_BYTES=4, MAX_FRAME_BYTES=8.

axis_frame_len is a combinatorial pass-through: m_axis_* = s_axis_* directly.
The error flags and frame_len_o are combinatorial and valid only when
m_valid=1, m_ready=1, m_last=1 (i.e. the last beat is being accepted).

Strategy: capture the status signals INLINE on the last accepted beat, at the
RisingEdge callback.  In CocoTB + GHDL the RisingEdge callback fires before
the VHDL sequential (registered) processes update their outputs, so byte_cnt
still reflects the accumulated count from the previous beats.

Tests:
  1. Normal frame (6 bytes) – no error, frame_len_o=6.
  2. Short  frame (2 bytes) – err_short asserted.
  3. Long   frame (10 bytes) – err_long asserted.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset_dut(dut, cycles=3):
    """Apply active-low reset."""
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


async def send_packet_capture_status(dut, num_beats):
    """Send a packet and capture (frame_len, err_short, err_long) at the last
    accepted beat.  The capture happens inline at the RisingEdge of the last
    beat so that the combinatorial outputs are still valid.
    """
    frame_len = 0
    err_short = 0
    err_long = 0

    for i in range(1, num_beats + 1):
        dut.s_axis_tdata.value = i & 0xFF
        dut.s_axis_tlast.value = 1 if i == num_beats else 0
        dut.s_axis_tvalid.value = 1
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.s_axis_tready.value) == 1:
                # Capture status on the last accepted beat before deassert.
                # At the RisingEdge callback, byte_cnt has not yet been reset
                # by the VHDL registered process, so frame_len_o is correct.
                if i == num_beats:
                    frame_len = int(dut.frame_len_o.value)
                    err_short = int(dut.err_short_o.value)
                    err_long  = int(dut.err_long_o.value)
                break

    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    return frame_len, err_short, err_long


@cocotb.test()
async def test_normal_frame(dut):
    """6-byte frame: no error expected, frame_len_o must equal 6."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    frame_len, err_short, err_long = await send_packet_capture_status(dut, 6)

    assert err_short == 0, f"Unexpected err_short for 6-byte frame"
    assert err_long == 0,  f"Unexpected err_long for 6-byte frame"
    assert frame_len == 6, f"frame_len mismatch: expected 6, got {frame_len}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_normal_frame")


@cocotb.test()
async def test_short_frame(dut):
    """2-byte frame: err_short must be asserted (MIN=4)."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    frame_len, err_short, err_long = await send_packet_capture_status(dut, 2)

    assert err_short == 1, "Expected err_short for 2-byte frame"
    assert err_long == 0,  "Unexpected err_long for 2-byte frame"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_short_frame")


@cocotb.test()
async def test_long_frame(dut):
    """10-byte frame: err_long must be asserted (MAX=8)."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    frame_len, err_short, err_long = await send_packet_capture_status(dut, 10)

    assert err_short == 0, "Unexpected err_short for 10-byte frame"
    assert err_long == 1,  "Expected err_long for 10-byte frame"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_long_frame")
