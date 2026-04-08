"""CocoTB test suite for the crc16 VHDL module.

Verifies two standard CRC16 variants against the industry-standard
test vector "123456789" (ASCII bytes 0x31..0x39):

  CRC16-CCITT  expected: 0x29B1
  CRC16-IBM    expected: 0xBB3D

Also verifies check (receiver) mode: feeding the message followed by
its appended CRC bytes back through the calculator must produce a
zero residue for both variants.

  CRC-CCITT: append checksum big-endian  {0x29, 0xB1} -> residue 0x0000
  CRC-IBM  : append checksum little-endian {0x3D, 0xBB} -> residue 0x0000
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

# "123456789" in ASCII
MSG = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39]


async def reset_dut(dut, cycles=2):
    """Apply synchronous reset for *cycles* clock edges."""
    dut.rst.value = 1
    dut.clr.value = 0
    dut.valid.value = 0
    dut.data_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


async def send_bytes(dut, data):
    """Clock *data* bytes into both DUTs one byte per rising edge."""
    for byte in data:
        dut.data_in.value = byte
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    dut.valid.value = 0
    await RisingEdge(dut.clk)  # let the final word settle


@cocotb.test()
async def test_ccitt_generator(dut):
    """CRC16-CCITT generator: '123456789' must produce 0x29B1."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    await send_bytes(dut, MSG)

    result = int(dut.crc_ccitt.value)
    assert result == 0x29B1, (
        f"FAIL CRC16-CCITT generator: expected 0x29B1, got 0x{result:04X}"
    )
    dut._log.info(f"PASS CRC16-CCITT generator: 0x{result:04X}")


@cocotb.test()
async def test_ibm_generator(dut):
    """CRC16-IBM generator: '123456789' must produce 0xBB3D."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    await send_bytes(dut, MSG)

    result = int(dut.crc_ibm.value)
    assert result == 0xBB3D, (
        f"FAIL CRC16-IBM generator: expected 0xBB3D, got 0x{result:04X}"
    )
    dut._log.info(f"PASS CRC16-IBM generator: 0x{result:04X}")


@cocotb.test()
async def test_ccitt_check_residue(dut):
    """CRC16-CCITT check mode: message + {0x29,0xB1} must produce residue 0x0000."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    # First pass: confirm the generator result before clearing.
    await send_bytes(dut, MSG)

    # Clear and feed message + appended CRC bytes.
    dut.clr.value = 1
    await RisingEdge(dut.clk)
    dut.clr.value = 0

    ccitt_crc_bytes = [0x29, 0xB1]
    await send_bytes(dut, MSG)
    await send_bytes(dut, ccitt_crc_bytes)

    result = int(dut.crc_ccitt.value)
    assert result == 0x0000, (
        f"FAIL CRC16-CCITT check residue: expected 0x0000, got 0x{result:04X}"
    )
    dut._log.info(f"PASS CRC16-CCITT check residue: 0x{result:04X}")


@cocotb.test()
async def test_ibm_check_residue(dut):
    """CRC16-IBM check mode: message + {0x3D,0xBB} must produce residue 0x0000."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    # First pass: confirm the generator result before clearing.
    await send_bytes(dut, MSG)

    # Clear and feed message + appended CRC bytes.
    dut.clr.value = 1
    await RisingEdge(dut.clk)
    dut.clr.value = 0

    ibm_crc_bytes = [0x3D, 0xBB]
    await send_bytes(dut, MSG)
    await send_bytes(dut, ibm_crc_bytes)

    result = int(dut.crc_ibm.value)
    assert result == 0x0000, (
        f"FAIL CRC16-IBM check residue: expected 0x0000, got 0x{result:04X}"
    )
    dut._log.info(f"PASS CRC16-IBM check residue: 0x{result:04X}")
