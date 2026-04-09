-- =============================================================================
-- axis_crc16_insert_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_crc16_insert.
--
-- Instantiates axis_crc16_insert with DATA_WIDTH=8 and CRC16-CCITT defaults
-- so that the Python CocoTB test can drive and observe the inserter.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.crc16_pkg.all;

entity axis_crc16_insert_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (output) interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tlast  : out std_logic
    );
end entity axis_crc16_insert_cocotb_tb;

architecture tb of axis_crc16_insert_cocotb_tb is
begin

    dut : entity work.axis_crc16_insert
        generic map (
            DATA_WIDTH => 8,
            POLY       => x"1021",
            CRC_INIT   => x"FFFF",
            REFIN      => false,
            REFOUT     => false,
            XOROUT     => x"0000"
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tlast  => s_axis_tlast,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tlast  => m_axis_tlast
        );

end architecture tb;
