-- =============================================================================
-- axis_broadcaster_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_broadcaster.
--
-- Instantiates axis_broadcaster with N_PORTS=3, DATA_WIDTH=8 so the Python
-- CocoTB testbench can drive and observe the 1-to-3 broadcaster.
--
-- For N=3, DATA_WIDTH=8 the flat-vector output ports are 24 bits wide.
-- Port ordering: port 0 occupies the LSBs.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity axis_broadcaster_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tkeep  : in  std_logic_vector(0 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (3 outputs) – flat vectors, port k at [(k+1)*8-1:k*8]
        m_axis_tvalid : out std_logic_vector(2 downto 0);
        m_axis_tready : in  std_logic_vector(2 downto 0);
        m_axis_tdata  : out std_logic_vector(23 downto 0);
        m_axis_tkeep  : out std_logic_vector(2 downto 0);
        m_axis_tlast  : out std_logic_vector(2 downto 0)
    );
end entity axis_broadcaster_cocotb_tb;

architecture tb of axis_broadcaster_cocotb_tb is
begin

    dut : entity work.axis_broadcaster
        generic map (
            N_PORTS    => 3,
            DATA_WIDTH => 8,
            USER_WIDTH => 1,
            ID_WIDTH   => 1,
            DEST_WIDTH => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tkeep  => s_axis_tkeep,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => (others => '0'),
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tkeep  => m_axis_tkeep,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

end architecture tb;
