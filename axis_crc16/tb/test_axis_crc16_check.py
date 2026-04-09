"""CocoTB test suite for axis_crc16_check.

DUT: axis_crc16_check with DATA_WIDTH=8, CRC16-CCITT
     (POLY=0x1021, INIT=0xFFFF, REFIN=false, REFOUT=false, XOROUT=0x0000,
      CRC_RESIDUE=0x0000)

The checker receives an AXIS packet whose last two bytes are the CRC16-CCITT
checksum appended big-endian (MSB first, then LSB).  It feeds all bytes
through its internal CRC16 calculator.  The residue equals 0x0000 when the
CRC is correct.

Timing of crc_ok_o / crc_err_o
-------------------------------
These signals are combinatorial and are valid exactly ONE rising-edge AFTER
the last beat (tlast) is accepted.  Internally the module asserts
clr_pending='1' for that one cycle (a stall that resets the CRC calculator).
The test therefore:
  1. Sends the full packet (payload + CRC bytes).
  2. Waits for one extra RisingEdge after the last beat is accepted.
  3. Samples crc_ok_o / crc_err_o at that point.

Reference test vector:
  "123456789" (0x31..0x39) + [0x29, 0xB1]  ->  residue = 0x0000  (ok)
  "123456789" (0x31..0x39) + [0x00, 0x00]  ->  residue != 0x0000 (error)

Tests:
  1. test_check_valid_crc      – correct CRC bytes -> crc_ok_o='1'.
  2. test_check_invalid_crc    – wrong CRC bytes   -> crc_err_o='1'.
  3. test_check_passthrough    – verify data passes through unmodified.
  4. test_check_multiple_frames – two frames; each checked independently.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

# "123456789" in ASCII
MSG_STD = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
# CRC16-CCITT of "123456789" = 0x29B1 (big-endian)
CRC_GOOD = [0x29, 0xB1]
CRC_BAD  = [0x00, 0x00]


async def reset_dut(dut, cycles=3):
    """Apply active-low reset for *cycles* clock edges."""
    dut.aresetn.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def send_packet_get_status(dut, packet):
    """Send *packet* (payload + appended CRC bytes) through the checker.

    Returns (crc_ok, crc_err, output_bytes):
      crc_ok / crc_err are sampled one cycle after the last beat is accepted
      (when clr_pending='1' and crc_out has the final residue).
      output_bytes is the list of pass-through output bytes.
    """
    dut.m_axis_tready.value = 1
    output_bytes = []

    for i, byte in enumerate(packet):
        is_last = (i == len(packet) - 1)
        dut.s_axis_tdata.value = byte
        dut.s_axis_tlast.value = 1 if is_last else 0
        dut.s_axis_tvalid.value = 1

        while True:
            await RisingEdge(dut.aclk)
            # Collect pass-through output on every accepted beat.
            if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tready.value) == 1:
                output_bytes.append(int(dut.m_axis_tdata.value))
            if int(dut.s_axis_tready.value) == 1:
                break  # this byte was accepted

    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

    # Wait one more rising edge: clr_pending='1' now, crc_out has the final
    # residue (updated at the previous edge when the last byte was clocked in).
    await RisingEdge(dut.aclk)
    crc_ok  = int(dut.crc_ok_o.value)
    crc_err = int(dut.crc_err_o.value)

    # Wait for the stall cycle to complete before returning.
    await RisingEdge(dut.aclk)
    return crc_ok, crc_err, output_bytes


@cocotb.test()
async def test_check_valid_crc(dut):
    """'123456789' + correct CRC [0x29, 0xB1] -> crc_ok_o must be 1."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    packet = MSG_STD + CRC_GOOD
    crc_ok, crc_err, _ = await send_packet_get_status(dut, packet)

    assert crc_ok  == 1, f"Expected crc_ok=1, got {crc_ok}"
    assert crc_err == 0, f"Expected crc_err=0, got {crc_err}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_check_valid_crc")


@cocotb.test()
async def test_check_invalid_crc(dut):
    """'123456789' + wrong CRC [0x00, 0x00] -> crc_err_o must be 1."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    packet = MSG_STD + CRC_BAD
    crc_ok, crc_err, _ = await send_packet_get_status(dut, packet)

    assert crc_ok  == 0, f"Expected crc_ok=0, got {crc_ok}"
    assert crc_err == 1, f"Expected crc_err=1, got {crc_err}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_check_invalid_crc")


@cocotb.test()
async def test_check_passthrough(dut):
    """All input bytes (including CRC bytes) must appear unmodified on output."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    packet = MSG_STD + CRC_GOOD
    _, _, output_bytes = await send_packet_get_status(dut, packet)

    assert output_bytes == packet, \
        f"Pass-through mismatch:\n  expected: {packet}\n  got:      {output_bytes}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_check_passthrough")


@cocotb.test()
async def test_check_multiple_frames(dut):
    """Two consecutive frames; CRC state must reset between them."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    # Frame 1: valid CRC
    packet1 = MSG_STD + CRC_GOOD
    crc_ok1, crc_err1, _ = await send_packet_get_status(dut, packet1)

    # Frame 2: invalid CRC (same message, wrong CRC bytes)
    packet2 = MSG_STD + CRC_BAD
    crc_ok2, crc_err2, _ = await send_packet_get_status(dut, packet2)

    assert crc_ok1  == 1, f"Frame 1: expected crc_ok=1,  got {crc_ok1}"
    assert crc_err1 == 0, f"Frame 1: expected crc_err=0, got {crc_err1}"
    assert crc_ok2  == 0, f"Frame 2: expected crc_ok=0,  got {crc_ok2}"
    assert crc_err2 == 1, f"Frame 2: expected crc_err=1, got {crc_err2}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_check_multiple_frames")
