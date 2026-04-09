-- =============================================================================
-- axis_mux_demux_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_mux and axis_demux.
--
-- Instantiates:
--   u_mux   : axis_mux   with N_PORTS=2, DATA_WIDTH=8, ARB_TYPE=1 (round-robin)
--   u_demux : axis_demux with N_PORTS=2, DATA_WIDTH=8, USE_TDEST=1
--
-- For N=2, DATA_WIDTH=8 the flat-vector ports are:
--   mux slave:  tdata[15:0]  tkeep[1:0]  tvalid[1:0]  tlast[1:0]
--   demux master: tdata[15:0] tkeep[1:0] tvalid[1:0]  tlast[1:0]
-- Port ordering: port 0 occupies the LSBs.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity axis_mux_demux_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- =====================================================================
        -- MUX inputs (2 ports, DATA_WIDTH=8)
        -- =====================================================================
        mux_s_tvalid : in  std_logic_vector(1 downto 0);
        mux_s_tready : out std_logic_vector(1 downto 0);
        mux_s_tdata  : in  std_logic_vector(15 downto 0);
        mux_s_tkeep  : in  std_logic_vector(1 downto 0);
        mux_s_tlast  : in  std_logic_vector(1 downto 0);

        -- MUX output
        mux_m_tvalid : out std_logic;
        mux_m_tready : in  std_logic;
        mux_m_tdata  : out std_logic_vector(7 downto 0);
        mux_m_tkeep  : out std_logic_vector(0 downto 0);
        mux_m_tlast  : out std_logic;

        -- =====================================================================
        -- DEMUX input
        -- =====================================================================
        dmx_s_tvalid : in  std_logic;
        dmx_s_tready : out std_logic;
        dmx_s_tdata  : in  std_logic_vector(7 downto 0);
        dmx_s_tkeep  : in  std_logic_vector(0 downto 0);
        dmx_s_tlast  : in  std_logic;
        dmx_s_tdest  : in  std_logic_vector(0 downto 0);

        -- DEMUX outputs (2 ports, DATA_WIDTH=8)
        dmx_m_tvalid : out std_logic_vector(1 downto 0);
        dmx_m_tready : in  std_logic_vector(1 downto 0);
        dmx_m_tdata  : out std_logic_vector(15 downto 0);
        dmx_m_tkeep  : out std_logic_vector(1 downto 0);
        dmx_m_tlast  : out std_logic_vector(1 downto 0)
    );
end entity axis_mux_demux_cocotb_tb;

architecture tb of axis_mux_demux_cocotb_tb is
begin

    -- 2-to-1 MUX (round-robin)
    u_mux : entity work.axis_mux
        generic map (
            N_PORTS    => 2,
            DATA_WIDTH => 8,
            USER_WIDTH => 1,
            ID_WIDTH   => 1,
            DEST_WIDTH => 1,
            ARB_TYPE   => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => mux_s_tvalid,
            s_axis_tready => mux_s_tready,
            s_axis_tdata  => mux_s_tdata,
            s_axis_tkeep  => mux_s_tkeep,
            s_axis_tlast  => mux_s_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => (others => '0'),
            m_axis_tvalid => mux_m_tvalid,
            m_axis_tready => mux_m_tready,
            m_axis_tdata  => mux_m_tdata,
            m_axis_tkeep  => mux_m_tkeep,
            m_axis_tlast  => mux_m_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

    -- 1-to-2 DEMUX (routed by tdest)
    u_demux : entity work.axis_demux
        generic map (
            N_PORTS    => 2,
            DATA_WIDTH => 8,
            USER_WIDTH => 1,
            ID_WIDTH   => 1,
            DEST_WIDTH => 1,
            USE_TDEST  => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            select_i      => (others => '0'),
            s_axis_tvalid => dmx_s_tvalid,
            s_axis_tready => dmx_s_tready,
            s_axis_tdata  => dmx_s_tdata,
            s_axis_tkeep  => dmx_s_tkeep,
            s_axis_tlast  => dmx_s_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => dmx_s_tdest,
            m_axis_tvalid => dmx_m_tvalid,
            m_axis_tready => dmx_m_tready,
            m_axis_tdata  => dmx_m_tdata,
            m_axis_tkeep  => dmx_m_tkeep,
            m_axis_tlast  => dmx_m_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

end architecture tb;
