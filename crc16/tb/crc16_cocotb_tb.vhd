-- CocoTB top-level wrapper for crc16
--
-- Instantiates two crc16 DUTs with fixed generics so the Python
-- CocoTB testbench can drive and observe both configurations:
--
--   crc_ccitt : CRC16-CCITT  (poly=0x1021, init=0xFFFF, no reflection)
--   crc_ibm   : CRC16-IBM    (poly=0x8005, init=0x0000, reflected I/O)
--
-- All control / data inputs are shared; each DUT exposes its own
-- CRC output and running-parity output.

library ieee;
use ieee.std_logic_1164.all;
use work.crc16_pkg.all;

entity crc16_cocotb_tb is
    port (
        clk       : in  std_logic;
        rst       : in  std_logic;
        clr       : in  std_logic;
        valid     : in  std_logic;
        data_in   : in  std_logic_vector(7 downto 0);
        crc_ccitt : out std_logic_vector(15 downto 0);
        crc_ibm   : out std_logic_vector(15 downto 0);
        par_ccitt : out std_logic;
        par_ibm   : out std_logic
    );
end entity crc16_cocotb_tb;

architecture tb of crc16_cocotb_tb is
begin

    -- -----------------------------------------------------------------------
    -- DUT 1: CRC16-CCITT  (poly=0x1021, init=0xFFFF, no reflection)
    -- -----------------------------------------------------------------------
    dut_ccitt : entity work.crc16
        generic map (
            DATA_WIDTH => 8,
            POLY       => x"1021",
            CRC_INIT   => x"FFFF",
            REFIN      => false,
            REFOUT     => false,
            XOROUT     => x"0000"
        )
        port map (
            clk    => clk,
            rst    => rst,
            clr    => clr,
            valid  => valid,
            data   => data_in,
            crc    => crc_ccitt,
            parity => par_ccitt
        );

    -- -----------------------------------------------------------------------
    -- DUT 2: CRC16-IBM  (poly=0x8005, init=0x0000, reflected I/O)
    -- -----------------------------------------------------------------------
    dut_ibm : entity work.crc16
        generic map (
            DATA_WIDTH => 8,
            POLY       => x"8005",
            CRC_INIT   => x"0000",
            REFIN      => true,
            REFOUT     => true,
            XOROUT     => x"0000"
        )
        port map (
            clk    => clk,
            rst    => rst,
            clr    => clr,
            valid  => valid,
            data   => data_in,
            crc    => crc_ibm,
            parity => par_ibm
        );

end architecture tb;
