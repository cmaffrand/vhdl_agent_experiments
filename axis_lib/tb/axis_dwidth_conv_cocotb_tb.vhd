-- =============================================================================
-- axis_dwidth_conv_cocotb_tb.vhd
-- CocoTB top-level wrapper for axis_dwidth_conv.
--
-- Instantiates two DUTs:
--   u_upsize   : 8-bit input  -> 32-bit output (upsizer)
--   u_downsize : 32-bit input -> 8-bit  output (downsizer)
--
-- Ports are prefixed "up_" and "dn_" respectively.  Clock and reset are shared.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

entity axis_dwidth_conv_cocotb_tb is
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- =====================================================================
        -- Upsizer  8 -> 32
        -- =====================================================================
        up_s_tvalid : in  std_logic;
        up_s_tready : out std_logic;
        up_s_tdata  : in  std_logic_vector(7 downto 0);
        up_s_tkeep  : in  std_logic_vector(0 downto 0);
        up_s_tlast  : in  std_logic;

        up_m_tvalid : out std_logic;
        up_m_tready : in  std_logic;
        up_m_tdata  : out std_logic_vector(31 downto 0);
        up_m_tkeep  : out std_logic_vector(3 downto 0);
        up_m_tlast  : out std_logic;

        -- =====================================================================
        -- Downsizer  32 -> 8
        -- =====================================================================
        dn_s_tvalid : in  std_logic;
        dn_s_tready : out std_logic;
        dn_s_tdata  : in  std_logic_vector(31 downto 0);
        dn_s_tkeep  : in  std_logic_vector(3 downto 0);
        dn_s_tlast  : in  std_logic;

        dn_m_tvalid : out std_logic;
        dn_m_tready : in  std_logic;
        dn_m_tdata  : out std_logic_vector(7 downto 0);
        dn_m_tkeep  : out std_logic_vector(0 downto 0);
        dn_m_tlast  : out std_logic
    );
end entity axis_dwidth_conv_cocotb_tb;

architecture tb of axis_dwidth_conv_cocotb_tb is
begin

    -- 8 -> 32 upsizer
    u_upsize : entity work.axis_dwidth_conv
        generic map (
            S_DATA_WIDTH => 8,
            M_DATA_WIDTH => 32,
            USER_WIDTH   => 1,
            ID_WIDTH     => 1,
            DEST_WIDTH   => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => up_s_tvalid,
            s_axis_tready => up_s_tready,
            s_axis_tdata  => up_s_tdata,
            s_axis_tkeep  => up_s_tkeep,
            s_axis_tlast  => up_s_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => (others => '0'),
            m_axis_tvalid => up_m_tvalid,
            m_axis_tready => up_m_tready,
            m_axis_tdata  => up_m_tdata,
            m_axis_tkeep  => up_m_tkeep,
            m_axis_tlast  => up_m_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

    -- 32 -> 8 downsizer
    u_downsize : entity work.axis_dwidth_conv
        generic map (
            S_DATA_WIDTH => 32,
            M_DATA_WIDTH => 8,
            USER_WIDTH   => 1,
            ID_WIDTH     => 1,
            DEST_WIDTH   => 1
        )
        port map (
            aclk          => aclk,
            aresetn       => aresetn,
            s_axis_tvalid => dn_s_tvalid,
            s_axis_tready => dn_s_tready,
            s_axis_tdata  => dn_s_tdata,
            s_axis_tkeep  => dn_s_tkeep,
            s_axis_tlast  => dn_s_tlast,
            s_axis_tuser  => (others => '0'),
            s_axis_tid    => (others => '0'),
            s_axis_tdest  => (others => '0'),
            m_axis_tvalid => dn_m_tvalid,
            m_axis_tready => dn_m_tready,
            m_axis_tdata  => dn_m_tdata,
            m_axis_tkeep  => dn_m_tkeep,
            m_axis_tlast  => dn_m_tlast,
            m_axis_tuser  => open,
            m_axis_tid    => open,
            m_axis_tdest  => open
        );

end architecture tb;
