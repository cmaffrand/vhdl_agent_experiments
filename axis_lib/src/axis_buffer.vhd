-- =============================================================================
-- axis_buffer.vhd
-- Single-stage AXI-Stream pipeline register (skid buffer).
-- Breaks combinatorial paths between master and slave, adding 1-cycle latency.
-- Fully compatible with AXI-Stream backpressure (tready).
-- =============================================================================
-- Generics:
--   DATA_WIDTH  : tdata width in bits  (default 8)
--   KEEP_ENABLE : include tkeep signal  (default 1 = yes)
--   LAST_ENABLE : include tlast signal  (default 1 = yes)
--   USER_WIDTH  : tuser width in bits  (default 1, 0 = disabled)
--   ID_WIDTH    : tid   width in bits  (default 1, 0 = disabled)
--   DEST_WIDTH  : tdest width in bits  (default 1, 0 = disabled)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_buffer is
    generic (
        DATA_WIDTH  : positive := 8;
        KEEP_ENABLE : natural  := 1;
        LAST_ENABLE : natural  := 1;
        USER_WIDTH  : natural  := 1;
        ID_WIDTH    : natural  := 1;
        DEST_WIDTH  : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic_vector(USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master (output) interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0)
    );
end entity axis_buffer;

architecture rtl of axis_buffer is

    signal buf_valid : std_logic                                   := '0';
    signal buf_data  : std_logic_vector(DATA_WIDTH - 1 downto 0)  := (others => '0');
    signal buf_keep  : std_logic_vector((DATA_WIDTH/8) - 1 downto 0) := (others => '0');
    signal buf_last  : std_logic                                   := '0';
    signal buf_user  : std_logic_vector(USER_WIDTH - 1 downto 0)  := (others => '0');
    signal buf_id    : std_logic_vector(ID_WIDTH   - 1 downto 0)  := (others => '0');
    signal buf_dest  : std_logic_vector(DEST_WIDTH - 1 downto 0)  := (others => '0');

begin

    -- Skid-buffer register process
    -- Accept new data when either we have no data buffered or the downstream
    -- consumer is taking our current beat.
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                buf_valid <= '0';
            else
                if (m_axis_tready = '1' or buf_valid = '0') then
                    buf_valid <= s_axis_tvalid;
                    if s_axis_tvalid = '1' then
                        buf_data <= s_axis_tdata;
                        buf_last <= s_axis_tlast when LAST_ENABLE = 1 else '0';
                        buf_keep <= s_axis_tkeep when KEEP_ENABLE = 1 else (others => '1');
                        buf_user <= s_axis_tuser when USER_WIDTH > 0  else (others => '0');
                        buf_id   <= s_axis_tid   when ID_WIDTH   > 0  else (others => '0');
                        buf_dest <= s_axis_tdest when DEST_WIDTH > 0  else (others => '0');
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Ready when we can accept: either empty or being consumed this cycle
    s_axis_tready <= m_axis_tready or not buf_valid;

    m_axis_tvalid <= buf_valid;
    m_axis_tdata  <= buf_data;
    m_axis_tkeep  <= buf_keep;
    m_axis_tlast  <= buf_last;
    m_axis_tuser  <= buf_user;
    m_axis_tid    <= buf_id;
    m_axis_tdest  <= buf_dest;

end architecture rtl;
