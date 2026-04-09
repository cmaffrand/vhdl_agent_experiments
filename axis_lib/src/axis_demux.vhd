-- =============================================================================
-- axis_demux.vhd
-- AXI-Stream 1-to-N Demultiplexer.
-- Routes the single input stream to one of N output ports.
-- The destination is determined by s_axis_tdest (lower SEL_W bits) when
-- USE_TDEST=1, or by the external select_i signal otherwise.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_demux is
    generic (
        N_PORTS    : positive := 2;   -- Number of output ports
        DATA_WIDTH : positive := 8;
        USER_WIDTH : natural  := 1;
        ID_WIDTH   : natural  := 1;
        DEST_WIDTH : natural  := 1;
        USE_TDEST  : natural  := 1    -- 1 = use tdest, 0 = use select_i
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- External select (used when USE_TDEST=0)
        select_i : in  std_logic_vector(clog2(N_PORTS) - 1 downto 0) := (others => '0');

        -- Slave (single input)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic_vector(USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master (N outputs) – flat vectors, port k at [(k+1)*W-1:k*W]
        m_axis_tvalid : out std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tready : in  std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tdata  : out std_logic_vector(N_PORTS * DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector(N_PORTS * (DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tuser  : out std_logic_vector(N_PORTS * USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(N_PORTS * ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(N_PORTS * DEST_WIDTH - 1 downto 0)
    );
end entity axis_demux;

architecture rtl of axis_demux is

    constant KEEP_W : natural := DATA_WIDTH / 8;
    constant SEL_W  : natural := clog2(N_PORTS);

    -- Latch the route at start-of-packet so it stays fixed for the whole packet
    signal route      : unsigned(SEL_W - 1 downto 0) := (others => '0');
    signal in_packet  : std_logic := '0';

    signal dest_sel : unsigned(SEL_W - 1 downto 0);

begin

    dest_sel <= unsigned(s_axis_tdest(SEL_W - 1 downto 0)) when USE_TDEST = 1
                else unsigned(select_i);

    -- Latch route on first beat of packet
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                route     <= (others => '0');
                in_packet <= '0';
            else
                if in_packet = '0' and s_axis_tvalid = '1' then
                    -- Capture route
                    if dest_sel < N_PORTS then
                        route <= dest_sel;
                    else
                        route <= (others => '0');  -- clamp to port 0
                    end if;
                    in_packet <= '1';
                end if;
                if in_packet = '1'
                   and s_axis_tvalid = '1'
                   and m_axis_tready(to_integer(route)) = '1'
                   and s_axis_tlast = '1' then
                    in_packet <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Output combinatorial
    process (all) is
        variable r : natural range 0 to N_PORTS - 1;
    begin
        r := to_integer(route);

        m_axis_tvalid <= (others => '0');
        m_axis_tdata  <= (others => '0');
        m_axis_tkeep  <= (others => '0');
        m_axis_tlast  <= (others => '0');
        m_axis_tuser  <= (others => '0');
        m_axis_tid    <= (others => '0');
        m_axis_tdest  <= (others => '0');
        s_axis_tready <= '0';

        if in_packet = '1' then
            m_axis_tvalid(r) <= s_axis_tvalid;
            m_axis_tdata((r + 1) * DATA_WIDTH - 1 downto r * DATA_WIDTH) <= s_axis_tdata;
            m_axis_tkeep((r + 1) * KEEP_W     - 1 downto r * KEEP_W)    <= s_axis_tkeep;
            m_axis_tlast(r) <= s_axis_tlast;
            m_axis_tuser((r + 1) * USER_WIDTH - 1 downto r * USER_WIDTH) <= s_axis_tuser;
            m_axis_tid  ((r + 1) * ID_WIDTH   - 1 downto r * ID_WIDTH)   <= s_axis_tid;
            m_axis_tdest((r + 1) * DEST_WIDTH - 1 downto r * DEST_WIDTH) <= s_axis_tdest;
            s_axis_tready <= m_axis_tready(r);
        end if;
    end process;

end architecture rtl;
