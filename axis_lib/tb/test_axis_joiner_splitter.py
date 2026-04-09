"""CocoTB test suite for axis_joiner (N=2) and axis_splitter (SPLIT_BEAT=2).

Joiner (N=2, DATA_WIDTH=8):
  - 2 independent 8-bit inputs merged into one 16-bit output beat.
  - port 0 = join_s_tdata[7:0], port 1 = join_s_tdata[15:8]
  - output: join_m_tdata[15:0]

Splitter (DATA_WIDTH=8, SPLIT_BEAT=2):
  - First 2 beats -> output A (header), remaining beats -> output B (payload).

Tests:
  1. Joiner: present 0xAA on port 0 and 0xBB on port 1 simultaneously;
     verify joined output is 0xBBAA.
  2. Splitter: send 5-beat packet (values 1..5); beats 1-2 should appear on
     output A with tlast on beat 2, beats 3-5 should appear on output B with
     tlast on beat 5.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


DATA_W = 8


async def reset_dut(dut, cycles=3):
    """Apply active-low reset, idle all ports."""
    dut.aresetn.value = 0
    dut.join_s_tvalid.value = 0
    dut.join_s_tdata.value = 0
    dut.join_s_tkeep.value = 0x3
    dut.join_s_tlast.value = 0
    dut.join_m_tready.value = 1
    dut.spl_s_tvalid.value = 0
    dut.spl_s_tdata.value = 0
    dut.spl_s_tkeep.value = 1
    dut.spl_s_tlast.value = 0
    dut.spl_a_tready.value = 1
    dut.spl_b_tready.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


@cocotb.test()
async def test_joiner(dut):
    """Both ports simultaneously valid; output must be {0xBB, 0xAA}=0xBBAA."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.join_m_tready.value = 1

    # Present both ports valid with data and last
    dut.join_s_tdata.value = (0xBB << DATA_W) | 0xAA  # port1=0xBB, port0=0xAA
    dut.join_s_tlast.value = 0x3  # both last
    dut.join_s_tvalid.value = 0x3  # both valid

    while True:
        await RisingEdge(dut.aclk)
        if int(dut.join_m_tvalid.value) == 1 and int(dut.join_m_tready.value) == 1:
            got = int(dut.join_m_tdata.value)
            port0 = got & 0xFF
            port1 = (got >> DATA_W) & 0xFF
            assert port0 == 0xAA, f"Joiner port 0 mismatch: expected 0xAA, got 0x{port0:02X}"
            assert port1 == 0xBB, f"Joiner port 1 mismatch: expected 0xBB, got 0x{port1:02X}"
            break

    dut.join_s_tvalid.value = 0
    await Timer(30, unit="ns")
    dut._log.info("PASS test_joiner")


@cocotb.test()
async def test_splitter(dut):
    """5-beat packet: beats 1-2 to A (with A-tlast on beat 2), beats 3-5 to B (B-tlast on beat 5)."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.spl_a_tready.value = 1
    dut.spl_b_tready.value = 1

    a_beats = []
    b_beats = []
    a_last_seen = False
    b_last_seen = False

    async def monitor_a():
        nonlocal a_last_seen
        while not a_last_seen:
            await RisingEdge(dut.aclk)
            if int(dut.spl_a_tvalid.value) == 1 and int(dut.spl_a_tready.value) == 1:
                a_beats.append(int(dut.spl_a_tdata.value))
                if int(dut.spl_a_tlast.value) == 1:
                    a_last_seen = True

    async def monitor_b():
        nonlocal b_last_seen
        while not b_last_seen:
            await RisingEdge(dut.aclk)
            if int(dut.spl_b_tvalid.value) == 1 and int(dut.spl_b_tready.value) == 1:
                b_beats.append(int(dut.spl_b_tdata.value))
                if int(dut.spl_b_tlast.value) == 1:
                    b_last_seen = True

    cocotb.start_soon(monitor_a())
    cocotb.start_soon(monitor_b())

    # Send 5-beat packet
    for i in range(1, 6):
        dut.spl_s_tdata.value = i
        dut.spl_s_tlast.value = 1 if i == 5 else 0
        dut.spl_s_tvalid.value = 1
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.spl_s_tready.value) == 1:
                break
    dut.spl_s_tvalid.value = 0
    dut.spl_s_tlast.value = 0

    # Wait until both monitors finish
    await Timer(100, unit="ns")

    assert a_beats == [1, 2], f"Splitter A beats: expected [1,2], got {a_beats}"
    assert b_beats == [3, 4, 5], f"Splitter B beats: expected [3,4,5], got {b_beats}"

    dut._log.info("PASS test_splitter")
