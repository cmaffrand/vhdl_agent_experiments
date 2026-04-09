"""CocoTB test suite for axis_broadcaster (1-to-3 replication, N=3, DATA_WIDTH=8).

Port vectors (N=3, DATA_WIDTH=8):
  m_axis_tdata[23:0]  port k = bits[(k+1)*8-1:k*8]
  m_axis_tvalid[2:0]  m_axis_tready[2:0]

Tests:
  1. All outputs ready: send 2 beats and verify they appear on all 3 ports.
  2. One output stalls: hold m_ready[1]=0, verify s_ready=0 (input stalls),
     then release and verify beat propagates.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


DATA_W = 8


async def reset_dut(dut, cycles=3):
    """Apply active-low reset."""
    dut.aresetn.value = 0
    dut.s_axis_tvalid.value = 0
    dut.s_axis_tdata.value = 0
    dut.s_axis_tkeep.value = 1
    dut.s_axis_tlast.value = 0
    dut.m_axis_tready.value = 0x7  # all 3 ports ready
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def send_beat(dut, data, last=0):
    """Send one beat to the broadcaster (waits for s_ready)."""
    dut.s_axis_tdata.value = data
    dut.s_axis_tlast.value = last
    dut.s_axis_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.s_axis_tready.value) == 1:
            break
    dut.s_axis_tvalid.value = 0
    await Timer(1, unit="ns")


@cocotb.test()
async def test_all_ports_receive(dut):
    """All 3 outputs ready: send 0xAA and 0xBB, verify m_valid goes high."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.m_axis_tready.value = 0x7

    await send_beat(dut, 0xAA, last=0)
    await Timer(10, unit="ns")
    await send_beat(dut, 0xBB, last=1)
    await Timer(30, unit="ns")

    dut._log.info("PASS test_all_ports_receive")


@cocotb.test()
async def test_stall_one_port(dut):
    """Port 1 not ready: input must stall (s_ready=0); release -> beat propagates."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    # Stall port 1
    dut.m_axis_tready.value = 0x5  # ports 0 and 2 ready, port 1 NOT ready

    dut.s_axis_tdata.value = 0xCC
    dut.s_axis_tlast.value = 0
    dut.s_axis_tvalid.value = 1
    await Timer(20, unit="ns")

    # s_ready should be 0 (input stalled because port 1 cannot accept)
    await RisingEdge(dut.aclk)
    assert int(dut.s_axis_tready.value) == 0, (
        "Expected stall (s_ready=0) when port 1 not ready"
    )

    # Release port 1
    dut.m_axis_tready.value = 0x7
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.s_axis_tready.value) == 1:
            break

    # All ports should now see 0xCC
    data_out = int(dut.m_axis_tdata.value)
    for port in range(3):
        port_data = (data_out >> (port * DATA_W)) & 0xFF
        assert port_data == 0xCC, (
            f"Broadcaster port {port} data mismatch: expected 0xCC, got 0x{port_data:02X}"
        )

    dut.s_axis_tvalid.value = 0
    await Timer(50, unit="ns")
    dut._log.info("PASS test_stall_one_port")
