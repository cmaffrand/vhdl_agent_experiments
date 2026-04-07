-- =============================================================================
-- axis_splitter.vhd
-- AXI-Stream Splitter.
-- Splits one input stream into two output streams:
--   - Output A: first SPLIT_BEAT beats of each packet (header)
--   - Output B: remaining beats of each packet (payload)
-- If the packet is shorter than SPLIT_BEAT beats, all beats go to output A.
-- SPLIT_BEAT = 0 means all beats go to output B.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_splitter is
    generic (
        DATA_WIDTH  : positive := 8;
        USER_WIDTH  : natural  := 1;
        ID_WIDTH    : natural  := 1;
        DEST_WIDTH  : natural  := 1;
        SPLIT_BEAT  : natural  := 1   -- Number of beats sent to output A (header)
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic_vector(USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master A (header output)
        m_axis_a_tvalid : out std_logic;
        m_axis_a_tready : in  std_logic;
        m_axis_a_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_a_tkeep  : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        m_axis_a_tlast  : out std_logic;
        m_axis_a_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_a_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_a_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master B (payload output)
        m_axis_b_tvalid : out std_logic;
        m_axis_b_tready : in  std_logic;
        m_axis_b_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_b_tkeep  : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        m_axis_b_tlast  : out std_logic;
        m_axis_b_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_b_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_b_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0)
    );
end entity axis_splitter;

architecture rtl of axis_splitter is

    constant BEAT_BITS : natural := clog2(SPLIT_BEAT + 1) + 1;

    signal beat_cnt  : unsigned(BEAT_BITS - 1 downto 0) := (others => '0');
    signal in_header : std_logic;
    signal downstream_ready : std_logic;
    signal a_last_beat : std_logic;

begin

    -- In header phase when beat_cnt < SPLIT_BEAT
    in_header <= '1' when (SPLIT_BEAT > 0 and beat_cnt < SPLIT_BEAT) else '0';

    -- Last beat of header section (only relevant when SPLIT_BEAT > 0)
    a_last_beat <= '1' when (SPLIT_BEAT > 0 and beat_cnt = SPLIT_BEAT - 1) else '0';

    -- Ready from the active downstream port
    downstream_ready <= m_axis_a_tready when in_header = '1' else m_axis_b_tready;
    s_axis_tready    <= downstream_ready;

    -- Beat counter
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                beat_cnt <= (others => '0');
            elsif s_axis_tvalid = '1' and downstream_ready = '1' then
                if s_axis_tlast = '1' then
                    beat_cnt <= (others => '0');
                else
                    beat_cnt <= beat_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Output A (header): valid during header beats
    m_axis_a_tvalid <= s_axis_tvalid and in_header;
    m_axis_a_tdata  <= s_axis_tdata;
    m_axis_a_tkeep  <= s_axis_tkeep;
    -- tlast on output A: when original packet ends OR when the last header beat arrives
    m_axis_a_tlast  <= s_axis_tlast or a_last_beat;
    m_axis_a_tuser  <= s_axis_tuser;
    m_axis_a_tid    <= s_axis_tid;
    m_axis_a_tdest  <= s_axis_tdest;

    -- Output B (payload): valid during payload beats
    m_axis_b_tvalid <= s_axis_tvalid and not in_header;
    m_axis_b_tdata  <= s_axis_tdata;
    m_axis_b_tkeep  <= s_axis_tkeep;
    m_axis_b_tlast  <= s_axis_tlast;
    m_axis_b_tuser  <= s_axis_tuser;
    m_axis_b_tid    <= s_axis_tid;
    m_axis_b_tdest  <= s_axis_tdest;

end architecture rtl;
