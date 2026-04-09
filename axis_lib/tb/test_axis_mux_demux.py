"""CocoTB test suite for axis_mux (2-to-1, round-robin) and axis_demux (1-to-2, tdest).

Port vectors (N=2, DATA_WIDTH=8):
  mux slave : mux_s_tdata[15:0]  port 0 = bits[7:0], port 1 = bits[15:8]
  dmx master: dmx_m_tdata[15:0]  port 0 = bits[7:0], port 1 = bits[15:8]

Tests:
  MUX: send 2-beat packet on port 0, then 1-beat packet on port 1 – expect 3 output beats.
  DEMUX: route beat to port 1 (tdest=1) then to port 0 (tdest=0) – verify data lands on right port.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


DATA_W = 8


async def reset_dut(dut, cycles=3):
    """Apply active-low reset, idle all ports."""
    dut.aresetn.value = 0
    dut.mux_s_tvalid.value = 0
    dut.mux_s_tdata.value = 0
    dut.mux_s_tkeep.value = 0x3
    dut.mux_s_tlast.value = 0
    dut.mux_m_tready.value = 1
    dut.dmx_s_tvalid.value = 0
    dut.dmx_s_tdata.value = 0
    dut.dmx_s_tkeep.value = 1
    dut.dmx_s_tlast.value = 0
    dut.dmx_s_tdest.value = 0
    dut.dmx_m_tready.value = 0x3
    for _ in range(cycles):
        await RisingEdge(dut.aclk)
    dut.aresetn.value = 1
    await RisingEdge(dut.aclk)


async def mux_send_beat(dut, port, data, last=0):
    """Send one beat on MUX input port *port* (0 or 1)."""
    cur_data = int(dut.mux_s_tdata.value)
    last_vec = int(dut.mux_s_tlast.value)
    # Update only the relevant port slice
    mask = (0xFF << (port * DATA_W))
    cur_data = (cur_data & ~mask) | ((data & 0xFF) << (port * DATA_W))
    last_vec = (last_vec & ~(1 << port)) | ((last & 1) << port)
    dut.mux_s_tdata.value = cur_data
    dut.mux_s_tlast.value = last_vec
    dut.mux_s_tvalid.value = int(dut.mux_s_tvalid.value) | (1 << port)

    while True:
        await RisingEdge(dut.aclk)
        if (int(dut.mux_s_tready.value) >> port) & 1 == 1:
            break

    # Deassert valid for this port
    valid = int(dut.mux_s_tvalid.value) & ~(1 << port)
    dut.mux_s_tvalid.value = valid
    # Clear last for this port
    dut.mux_s_tlast.value = int(dut.mux_s_tlast.value) & ~(1 << port)
    await Timer(1, unit="ns")


async def dmx_send_beat(dut, dest, data, last=0):
    """Send one beat to the DEMUX input with given *dest*."""
    dut.dmx_s_tdata.value = data
    dut.dmx_s_tdest.value = dest
    dut.dmx_s_tlast.value = last
    dut.dmx_s_tvalid.value = 1
    while True:
        await RisingEdge(dut.aclk)
        if int(dut.dmx_s_tready.value) == 1:
            break
    dut.dmx_s_tvalid.value = 0
    dut.dmx_s_tlast.value = 0
    await Timer(1, unit="ns")


@cocotb.test()
async def test_mux_two_ports(dut):
    """MUX: port 0 sends 2-beat packet then port 1 sends 1-beat packet -> 3 output beats."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    beats_rx = 0

    async def count_beats():
        nonlocal beats_rx
        dut.mux_m_tready.value = 1
        while True:
            await RisingEdge(dut.aclk)
            if int(dut.mux_m_tvalid.value) == 1 and int(dut.mux_m_tready.value) == 1:
                beats_rx += 1

    cocotb.start_soon(count_beats())

    await mux_send_beat(dut, port=0, data=0xA0, last=0)
    await mux_send_beat(dut, port=0, data=0xA1, last=1)
    await Timer(30, unit="ns")
    await mux_send_beat(dut, port=1, data=0xB0, last=1)
    await Timer(50, unit="ns")

    assert beats_rx == 3, f"MUX: expected 3 output beats, got {beats_rx}"
    dut._log.info("PASS test_mux_two_ports")


@cocotb.test()
async def test_demux_routing(dut):
    """DEMUX: route 0xCC to port 1 then 0xDD to port 0, verify data on correct port."""
    cocotb.start_soon(Clock(dut.aclk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.dmx_m_tready.value = 0x3  # both ports ready

    async def recv_demux(expected_port, expected_data):
        """Wait for the first accepted beat on the given DEMUX output port."""
        while True:
            await RisingEdge(dut.aclk)
            valid_vec = int(dut.dmx_m_tvalid.value)
            tready_vec = int(dut.dmx_m_tready.value)
            if (valid_vec >> expected_port) & 1 and (tready_vec >> expected_port) & 1:
                got = (int(dut.dmx_m_tdata.value) >> (expected_port * DATA_W)) & 0xFF
                assert got == expected_data, (
                    f"DEMUX port {expected_port}: expected 0x{expected_data:02X}, got 0x{got:02X}"
                )
                return

    # Route 0xCC to port 1 via tdest=1
    mon1 = cocotb.start_soon(recv_demux(expected_port=1, expected_data=0xCC))
    await dmx_send_beat(dut, dest=1, data=0xCC, last=1)
    await mon1

    # One idle clock between packets to ensure in_packet deasserts cleanly
    await RisingEdge(dut.aclk)

    # Route 0xDD to port 0 via tdest=0
    mon0 = cocotb.start_soon(recv_demux(expected_port=0, expected_data=0xDD))
    await dmx_send_beat(dut, dest=0, data=0xDD, last=1)
    await mon0

    await Timer(30, unit="ns")
    dut._log.info("PASS test_demux_routing")
