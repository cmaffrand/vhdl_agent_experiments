-- =============================================================================
-- axis_frame_len_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_frame_len.
--
-- Instantiates axis_frame_len with DATA_WIDTH=8, MIN_FRAME_BYTES=4,
-- MAX_FRAME_BYTES=8, LEN_BITS=16 so the Python CocoTB testbench can drive and
-- observe the frame-length checker.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axis_pkg.all;

entity axis_frame_len_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(7 downto 0);
        s_axis_tkeep  : in  std_logic_vector(0 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (output) interface – data passes through unchanged
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(7 downto 0);
        m_axis_tkeep  : out std_logic_vector(0 downto 0);
        m_axis_tlast  : out std_logic;

        -- Frame status outputs (valid on the tlast accepted cycle)
        frame_len_o : out std_logic_vector(15 downto 0);
        err_short_o : out std_logic;
        err_long_o  : out std_logic
    );
end entity axis_frame_len_cocotb_tb;

architecture tb of axis_frame_len_cocotb_tb is
begin

    dut : entity work.axis_frame_len
        generic map (
            DATA_WIDTH      => 8,
            USER_WIDTH      => 1,
            ID_WIDTH        => 1,
            DEST_WIDTH      => 1,
            MIN_FRAME_BYTES => 4,
            MAX_FRAME_BYTES => 8,
            LEN_BITS        => 16
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
            m_axis_tdest  => open,
            frame_len_o   => frame_len_o,
            err_short_o   => err_short_o,
            err_long_o    => err_long_o
        );

end architecture tb;
