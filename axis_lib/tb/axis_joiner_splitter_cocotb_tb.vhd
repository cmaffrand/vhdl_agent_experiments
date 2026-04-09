-- =============================================================================
-- axis_joiner_splitter_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_joiner and axis_splitter.
--
-- Instantiates:
--   u_joiner   : axis_joiner   with N_PORTS=2, DATA_WIDTH=8
--   u_splitter : axis_splitter with DATA_WIDTH=8, SPLIT_BEAT=2
--
-- Joiner: 2 independent 8-bit input streams merged into one 16-bit output beat.
-- Splitter: 1 input stream split at beat 2 -> output A (beats 0-1), B (rest).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.axis_pkg.all;

entity axis_joiner_splitter_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- =====================================================================
        -- Joiner inputs (2 ports, each 8 bits)
        -- =====================================================================
        join_s_tvalid : in  std_logic_vector(1 downto 0);
        join_s_tready : out std_logic_vector(1 downto 0);
        join_s_tdata  : in  std_logic_vector(15 downto 0);
        join_s_tkeep  : in  std_logic_vector(1 downto 0);
        join_s_tlast  : in  std_logic_vector(1 downto 0);

        -- Joiner output (16-bit wide)
        join_m_tvalid : out std_logic;
        join_m_tready : in  std_logic;
        join_m_tdata  : out std_logic_vector(15 downto 0);
        join_m_tkeep  : out std_logic_vector(1 downto 0);
        join_m_tlast  : out std_logic;

        -- =====================================================================
        -- Splitter input (8-bit)
        -- =====================================================================
        spl_s_tvalid : in  std_logic;
        spl_s_tready : out std_logic;
        spl_s_tdata  : in  std_logic_vector(7 downto 0);
        spl_s_tkeep  : in  std_logic_vector(0 downto 0);
        spl_s_tlast  : in  std_logic;

        -- Splitter output A (header, first SPLIT_BEAT=2 beats)
        spl_a_tvalid : out std_logic;
        spl_a_tready : in  std_logic;
        spl_a_tdata  : out std_logic_vector(7 downto 0);
        spl_a_tkeep  : out std_logic_vector(0 downto 0);
        spl_a_tlast  : out std_logic;

        -- Splitter output B (payload, remaining beats)
        spl_b_tvalid : out std_logic;
        spl_b_tready : in  std_logic;
        spl_b_tdata  : out std_logic_vector(7 downto 0);
        spl_b_tkeep  : out std_logic_vector(0 downto 0);
        spl_b_tlast  : out std_logic
    );
end entity axis_joiner_splitter_cocotb_tb;

architecture tb of axis_joiner_splitter_cocotb_tb is
begin

    -- 2-input joiner -> 16-bit output
    u_joiner : entity work.axis_joiner
        generic map (
            N_PORTS    => 2,
            DATA_WIDTH => 8,
            USER_WIDTH => 1,
            ID_WIDTH   => 1,
            DEST_WIDTH => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => join_s_tvalid,
            s_axis_tready => join_s_tready,
            s_axis_tdata  => join_s_tdata,
            s_axis_tkeep  => join_s_tkeep,
            s_axis_tlast  => join_s_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => (others => '0'),
            m_axis_tvalid => join_m_tvalid,
            m_axis_tready => join_m_tready,
            m_axis_tdata  => join_m_tdata,
            m_axis_tkeep  => join_m_tkeep,
            m_axis_tlast  => join_m_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

    -- Splitter: first 2 beats -> A (header), rest -> B (payload)
    u_splitter : entity work.axis_splitter
        generic map (
            DATA_WIDTH => 8,
            USER_WIDTH => 1,
            ID_WIDTH   => 1,
            DEST_WIDTH => 1,
            SPLIT_BEAT => 2
        )
        port map (
            aclk            => aclk,
            aresetn         => aresetn,
            s_axis_tvalid   => spl_s_tvalid,
            s_axis_tready   => spl_s_tready,
            s_axis_tdata    => spl_s_tdata,
            s_axis_tkeep    => spl_s_tkeep,
            s_axis_tlast    => spl_s_tlast,
            s_axis_tuser    => (others => '0'),
            s_axis_tid      => (others => '0'),
            s_axis_tdest    => (others => '0'),
            m_axis_a_tvalid => spl_a_tvalid,
            m_axis_a_tready => spl_a_tready,
            m_axis_a_tdata  => spl_a_tdata,
            m_axis_a_tkeep  => spl_a_tkeep,
            m_axis_a_tlast  => spl_a_tlast,
            m_axis_a_tuser  => open,
            m_axis_a_tid    => open,
            m_axis_a_tdest  => open,
            m_axis_b_tvalid => spl_b_tvalid,
            m_axis_b_tready => spl_b_tready,
            m_axis_b_tdata  => spl_b_tdata,
            m_axis_b_tkeep  => spl_b_tkeep,
            m_axis_b_tlast  => spl_b_tlast,
            m_axis_b_tuser  => open,
            m_axis_b_tid    => open,
            m_axis_b_tdest  => open
        );

end architecture tb;
