-- =============================================================================
-- axis_fifo_dp.vhd
-- AXI-Stream FIFO with Drop-Packet capability.
-- Incoming packets are written to the FIFO speculatively.  When a packet ends:
--   - If commit_i = '1' (or AUTO_COMMIT=1 and drop_i='0'), the packet is
--     committed and becomes visible to the reader.
--   - If drop_i = '1' the write pointer is rolled back to the last committed
--     write pointer, discarding the incomplete / erroneous packet.
--
-- This is useful when accepting variable-length frames from a MAC where CRC
-- errors are only known at end-of-frame.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_fifo_dp is
    generic (
        DATA_WIDTH   : positive := 8;
        DEPTH        : positive := 64;
        KEEP_ENABLE  : natural  := 1;
        LAST_ENABLE  : natural  := 1;
        USER_WIDTH   : natural  := 1;
        ID_WIDTH     : natural  := 1;
        DEST_WIDTH   : natural  := 1;
        -- When 1 the module auto-commits on tlast when drop_i='0'
        AUTO_COMMIT  : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Commit / Drop control (sampled on the cycle when tlast is accepted)
        -- commit_i and drop_i should be mutually exclusive.
        -- When AUTO_COMMIT=1 and neither is asserted the packet is auto-committed.
        commit_i : in  std_logic := '0';
        drop_i   : in  std_logic := '0';

        -- Status
        full  : out std_logic;
        empty : out std_logic;
        level : out std_logic_vector(clog2(DEPTH + 1) - 1 downto 0);

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
end entity axis_fifo_dp;

architecture rtl of axis_fifo_dp is

    constant ADDR_BITS : natural := clog2(DEPTH);
    constant KEEP_W    : natural := DATA_WIDTH / 8;
    constant WORD_W    : natural := DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH + DEST_WIDTH;
    constant CNT_BITS  : natural := clog2(DEPTH + 1);

    type ram_type is array (0 to DEPTH - 1) of std_logic_vector(WORD_W - 1 downto 0);
    signal ram : ram_type;

    -- wr_ptr      : speculative write pointer (rolls back on drop)
    -- wr_committed: last committed write pointer (stable, visible to reader)
    -- rd_ptr      : read pointer
    signal wr_ptr       : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal wr_committed : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal rd_ptr       : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');

    -- committed level (only committed words visible to reader)
    signal committed_cnt : unsigned(CNT_BITS - 1 downto 0) := (others => '0');
    -- speculative occupancy (includes in-flight un-committed words)
    signal spec_cnt      : unsigned(CNT_BITS - 1 downto 0) := (others => '0');

    signal full_i  : std_logic;
    signal empty_i : std_logic;

    signal wr_en         : std_logic;
    signal rd_en         : std_logic;
    signal last_accepted : std_logic;
    signal do_commit     : std_logic;
    signal do_drop       : std_logic;

    signal wr_word : std_logic_vector(WORD_W - 1 downto 0);
    signal rd_word : std_logic_vector(WORD_W - 1 downto 0);

begin

    -- Full based on speculative occupancy; empty based on committed
    full_i  <= '1' when spec_cnt = DEPTH else '0';
    empty_i <= '1' when committed_cnt = 0 else '0';

    wr_en <= s_axis_tvalid and not full_i;
    rd_en <= m_axis_tready and not empty_i;

    last_accepted <= wr_en and s_axis_tlast;

    -- Commit when last beat accepted and (explicit commit OR auto-commit with no drop)
    do_commit <= last_accepted and (commit_i or (not drop_i)) when AUTO_COMMIT = 1 else
                 last_accepted and commit_i;
    do_drop   <= last_accepted and drop_i;

    wr_word <= s_axis_tdest &
               s_axis_tid   &
               s_axis_tuser &
               s_axis_tlast &
               s_axis_tkeep &
               s_axis_tdata;

    -- Speculative write pointer and RAM write
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_ptr <= (others => '0');
            elsif do_drop = '1' then
                wr_ptr <= wr_committed;
            elsif wr_en = '1' then
                ram(to_integer(wr_ptr)) <= wr_word;
                wr_ptr <= wr_ptr + 1;
            end if;
        end if;
    end process;

    -- Committed write pointer (advances only on commit)
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_committed <= (others => '0');
            elsif do_commit = '1' then
                -- wr_ptr is still the current value; +1 will apply next cycle
                wr_committed <= wr_ptr + 1;
            end if;
        end if;
    end process;

    -- Read pointer
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                rd_ptr <= (others => '0');
            elsif rd_en = '1' then
                rd_ptr <= rd_ptr + 1;
            end if;
        end if;
    end process;

    -- Speculative count
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                spec_cnt <= (others => '0');
            elsif do_drop = '1' and rd_en = '0' then
                spec_cnt <= committed_cnt;
            elsif do_drop = '1' and rd_en = '1' then
                spec_cnt <= committed_cnt - 1;
            elsif wr_en = '1' and rd_en = '0' then
                spec_cnt <= spec_cnt + 1;
            elsif wr_en = '0' and rd_en = '1' then
                spec_cnt <= spec_cnt - 1;
            end if;
        end if;
    end process;

    -- Committed count
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                committed_cnt <= (others => '0');
            elsif do_commit = '1' and rd_en = '0' then
                committed_cnt <= spec_cnt + 1;
            elsif do_commit = '1' and rd_en = '1' then
                committed_cnt <= spec_cnt;
            elsif do_commit = '0' and rd_en = '1' then
                committed_cnt <= committed_cnt - 1;
            end if;
        end if;
    end process;

    -- Read output
    rd_word <= ram(to_integer(rd_ptr));

    m_axis_tdata  <= rd_word(DATA_WIDTH - 1 downto 0);
    m_axis_tkeep  <= rd_word(DATA_WIDTH + KEEP_W - 1 downto DATA_WIDTH);
    m_axis_tlast  <= rd_word(DATA_WIDTH + KEEP_W);
    m_axis_tuser  <= rd_word(DATA_WIDTH + KEEP_W + 1 + USER_WIDTH - 1
                             downto DATA_WIDTH + KEEP_W + 1);
    m_axis_tid    <= rd_word(DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH - 1
                             downto DATA_WIDTH + KEEP_W + 1 + USER_WIDTH);
    m_axis_tdest  <= rd_word(WORD_W - 1
                             downto DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH);

    m_axis_tvalid <= not empty_i;
    s_axis_tready <= not full_i;

    full  <= full_i;
    empty <= empty_i;
    level <= std_logic_vector(committed_cnt);

end architecture rtl;
