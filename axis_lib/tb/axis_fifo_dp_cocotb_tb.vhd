-- =============================================================================
-- axis_fifo_dp_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_fifo_dp (drop-packet FIFO).
--
-- Instantiates axis_fifo_dp with DATA_WIDTH=8, DEPTH=32, AUTO_COMMIT=1
-- so the Python CocoTB testbench can drive and observe the drop-packet FIFO.
-- level is 6 bits wide (clog2(32+1)=6).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axis_pkg.all;

entity axis_fifo_dp_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Commit / Drop control
        commit_i : in  std_logic;
        drop_i   : in  std_logic;

        -- FIFO status
        full    : out std_logic;
        empty   : out std_logic;
        level   : out std_logic_vector(5 downto 0);

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tkeep  : in  std_logic_vector(0 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (output) interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tkeep  : out std_logic_vector(0 downto 0);
        m_axis_tlast  : out std_logic
    );
end entity axis_fifo_dp_cocotb_tb;

architecture tb of axis_fifo_dp_cocotb_tb is
begin

    dut : entity work.axis_fifo_dp
        generic map (
            DATA_WIDTH  => 8,
            DEPTH       => 32,
            KEEP_ENABLE => 1,
            LAST_ENABLE => 1,
            USER_WIDTH  => 1,
            ID_WIDTH    => 1,
            DEST_WIDTH  => 1,
            AUTO_COMMIT => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            commit_i      => commit_i,
            drop_i        => drop_i,
            full          => full,
            empty         => empty,
            level         => level,
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
