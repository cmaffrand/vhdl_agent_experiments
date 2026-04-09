"""CocoTB test suite for axis_crc16_insert.

DUT: axis_crc16_insert with DATA_WIDTH=8, CRC16-CCITT
     (POLY=0x1021, INIT=0xFFFF, REFIN=false, REFOUT=false, XOROUT=0x0000)

The inserter appends two CRC bytes (big-endian: MSB first, then LSB) to every
input packet.  The output packet is exactly 2 bytes longer than the input.

Reference test vector:
  "123456789" (ASCII 0x31..0x39) -> CRC16-CCITT = 0x29B1
  Output:      [0x31..0x39, 0x29, 0xB1]  (11 bytes, tlast on 0xB1)

Output-capture strategy (sequential, no concurrency)
------------------------------------------------------
During the PASS state the DUT is a transparent pass-through:
  m_axis_tdata / m_axis_tvalid mirror s_axis_tdata / s_axis_tvalid.
At the RisingEdge callback where s_axis_tready=1 (beat accepted), the output
m_axis_tdata already holds the forwarded byte.  We therefore capture each
payload output byte INLINE at the acceptance callback.

After the last payload byte the DUT transitions to CRC1/CRC2 states and
drives m_axis_tvalid=1 automatically.  We wait for those two edges
sequentially to collect the two CRC bytes.

Tests:
  1. test_insert_known_vector    – "123456789" -> CRC = 0x29B1.
  2. test_insert_single_byte     – 1-byte payload -> 3-byte output.
  3. test_insert_back_pressure   – m_axis_tready=0 while CRC bytes are output.
  4. test_insert_multiple_frames – two back-to-back frames, independent CRCs.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

MSG_STD = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]
CRC_STD_HI = 0x29
CRC_STD_LO = 0xB1


def crc16_ccitt(data):
    """Python reference: CRC16-CCITT (POLY=0x1021, INIT=0xFFFF, no reflection)."""
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = (crc << 1) ^ 0x1021 if crc & 0x8000 else crc << 1
        crc &= 0xFFFF
    return crc


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


async def send_and_capture(dut, payload):
    """Send *payload* and return the complete output packet (payload + 2 CRC bytes).

    Capture strategy:
    - Each payload byte is captured INLINE at the acceptance callback: in PASS
      state m_axis_tdata mirrors s_axis_tdata, so we read it right when we see
      s_axis_tready=1.
    - After all payload bytes the DUT is in CRC1, then CRC2.  We wait for
      m_axis_tvalid=1 (which is always true in those states) to grab each CRC
      byte sequentially.

    m_axis_tready is held high throughout.
    """
    dut.m_axis_tready.value = 1
    received = []

    # Phase 1: send payload, capture each output byte at the acceptance edge.
    for i, byte in enumerate(payload):
        dut.s_axis_tdata.value = byte
        dut.s_axis_tlast.value = 1 if i == len(payload) - 1 else 0
        dut.s_axis_tvalid.value = 1
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.s_axis_tready.value) == 1:
                # m_axis_tdata is the pass-through of s_axis_tdata in PASS state.
                received.append(int(dut.m_axis_tdata.value))
                break

    # Phase 2: de-assert input, then capture the two CRC bytes.
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    for _ in range(2):
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tready.value) == 1:
                received.append(int(dut.m_axis_tdata.value))
                break

    return received


@cocotb.test()
async def test_insert_known_vector(dut):
    """Send '123456789', expect output appended with CRC16-CCITT = 0x29B1."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    received = await send_and_capture(dut, MSG_STD)

    assert len(received) == len(MSG_STD) + 2, \
        f"Output length mismatch: expected {len(MSG_STD) + 2}, got {len(received)}"
    assert received[:len(MSG_STD)] == MSG_STD, \
        f"Payload bytes corrupted: {received[:len(MSG_STD)]}"
    assert received[-2] == CRC_STD_HI, \
        f"CRC high byte: expected 0x{CRC_STD_HI:02X}, got 0x{received[-2]:02X}"
    assert received[-1] == CRC_STD_LO, \
        f"CRC low byte: expected 0x{CRC_STD_LO:02X}, got 0x{received[-1]:02X}"

    await Timer(30, unit="ns")
    dut._log.info("PASS test_insert_known_vector")


@cocotb.test()
async def test_insert_single_byte(dut):
    """Single-byte payload: output must be 3 bytes (data + 2 CRC bytes)."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    payload = [0xAB]
    expected_crc = crc16_ccitt(payload)

    received = await send_and_capture(dut, payload)

    assert len(received) == 3, \
        f"Expected 3 output bytes, got {len(received)}"
    assert received[0] == 0xAB, \
        f"Payload byte mismatch: expected 0xAB, got 0x{received[0]:02X}"
    got_crc = (received[1] << 8) | received[2]
    assert got_crc == expected_crc, \
        f"CRC mismatch: expected 0x{expected_crc:04X}, got 0x{got_crc:04X}"

    await Timer(30, unit="ns")
    dut._log.info(f"PASS test_insert_single_byte (CRC=0x{got_crc:04X})")


@cocotb.test()
async def test_insert_back_pressure(dut):
    """Hold m_axis_tready=0 during CRC byte output; verify correct CRC."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    payload = [0x01, 0x02, 0x03]
    expected_crc = crc16_ccitt(payload)
    received = []

    # Phase 1: send payload with m_axis_tready=1, capture payload output inline.
    dut.m_axis_tready.value = 1
    for i, byte in enumerate(payload):
        dut.s_axis_tdata.value = byte
        dut.s_axis_tlast.value = 1 if i == len(payload) - 1 else 0
        dut.s_axis_tvalid.value = 1
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.s_axis_tready.value) == 1:
                received.append(int(dut.m_axis_tdata.value))
                break

    # The last payload byte was accepted; DUT is now in CRC1 state.
    # De-assert input and hold m_axis_tready=0 for 2 cycles.
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 0
    await RisingEdge(dut.aclk)
    await RisingEdge(dut.aclk)

    # Phase 2: release back-pressure and collect the 2 CRC bytes.
    dut.m_axis_tready.value = 1
    for _ in range(2):
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.m_axis_tvalid.value) == 1 and int(dut.m_axis_tready.value) == 1:
                received.append(int(dut.m_axis_tdata.value))
                break

    assert received[:len(payload)] == payload, \
        f"Payload mismatch: {received[:len(payload)]} != {payload}"
    got_crc = (received[-2] << 8) | received[-1]
    assert got_crc == expected_crc, \
        f"CRC mismatch: expected 0x{expected_crc:04X}, got 0x{got_crc:04X}"

    await Timer(30, unit="ns")
    dut._log.info(f"PASS test_insert_back_pressure (CRC=0x{got_crc:04X})")


@cocotb.test()
async def test_insert_multiple_frames(dut):
    """Two frames back-to-back; each must get its own independent CRC."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    frame1 = [0x11, 0x22, 0x33]
    frame2 = [0xAA, 0xBB]
    crc1 = crc16_ccitt(frame1)
    crc2 = crc16_ccitt(frame2)

    received1 = await send_and_capture(dut, frame1)
    # Use explicit clock edges (not Timer) to avoid a Timer/rising-edge race in GHDL.
    await RisingEdge(dut.aclk)  # CRC2->PASS transition completes
    await RisingEdge(dut.aclk)  # CRC is fully reset, DUT ready for frame 2
    received2 = await send_and_capture(dut, frame2)

    got_crc1 = (received1[-2] << 8) | received1[-1]
    got_crc2 = (received2[-2] << 8) | received2[-1]

    assert received1[:len(frame1)] == frame1, \
        f"Frame 1 payload mismatch: {received1[:len(frame1)]}"
    assert received2[:len(frame2)] == frame2, \
        f"Frame 2 payload mismatch: {received2[:len(frame2)]}"
    assert got_crc1 == crc1, \
        f"Frame 1 CRC: expected 0x{crc1:04X}, got 0x{got_crc1:04X}"
    assert got_crc2 == crc2, \
        f"Frame 2 CRC: expected 0x{crc2:04X}, got 0x{got_crc2:04X}"

    await Timer(30, unit="ns")
    dut._log.info(
        f"PASS test_insert_multiple_frames "
        f"(CRC1=0x{got_crc1:04X}, CRC2=0x{got_crc2:04X})"
    )
