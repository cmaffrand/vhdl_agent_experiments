-- =============================================================================
-- axis_fifo.vhd
-- Synchronous AXI-Stream FIFO with configurable depth and data width.
-- Uses a circular buffer (RAM-based) with separate read/write pointers.
-- =============================================================================
-- Generics:
--   DATA_WIDTH  : tdata width in bits  (default 8)
--   DEPTH       : number of beats to store (must be power of 2)
--   KEEP_ENABLE : include tkeep signal  (default 1)
--   LAST_ENABLE : include tlast signal  (default 1)
--   USER_WIDTH  : tuser width in bits  (default 1, 0 = disabled)
--   ID_WIDTH    : tid   width in bits  (default 1, 0 = disabled)
--   DEST_WIDTH  : tdest width in bits  (default 1, 0 = disabled)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_fifo is
    generic (
        DATA_WIDTH  : positive := 8;
        DEPTH       : positive := 16;
        KEEP_ENABLE : natural  := 1;
        LAST_ENABLE : natural  := 1;
        USER_WIDTH  : natural  := 1;
        ID_WIDTH    : natural  := 1;
        DEST_WIDTH  : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

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
end entity axis_fifo;

architecture rtl of axis_fifo is

    constant ADDR_BITS : natural := clog2(DEPTH);
    constant KEEP_W    : natural := DATA_WIDTH / 8;

    -- Combined word stored in the RAM
    -- Layout: [tdest | tid | tuser | tlast | tkeep | tdata]
    constant WORD_W : natural := DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH + DEST_WIDTH;

    type ram_type is array (0 to DEPTH - 1) of std_logic_vector(WORD_W - 1 downto 0);
    signal ram : ram_type;

    signal wr_ptr  : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal rd_ptr  : unsigned(ADDR_BITS - 1 downto 0) := (others => '0');
    signal count   : unsigned(clog2(DEPTH + 1) - 1 downto 0) := (others => '0');

    signal full_i  : std_logic;
    signal empty_i : std_logic;

    -- Write and read data words
    signal wr_word : std_logic_vector(WORD_W - 1 downto 0);
    signal rd_word : std_logic_vector(WORD_W - 1 downto 0);

    signal wr_en : std_logic;
    signal rd_en : std_logic;

begin

    full_i  <= '1' when count = DEPTH else '0';
    empty_i <= '1' when count = 0     else '0';

    wr_en <= s_axis_tvalid and not full_i;
    rd_en <= m_axis_tready and not empty_i;

    -- Pack write word
    wr_word <= s_axis_tdest &
               s_axis_tid   &
               s_axis_tuser &
               s_axis_tlast &
               s_axis_tkeep &
               s_axis_tdata;

    -- Write pointer and RAM write
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                wr_ptr <= (others => '0');
            elsif wr_en = '1' then
                ram(to_integer(wr_ptr)) <= wr_word;
                wr_ptr <= wr_ptr + 1;
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

    -- Level counter
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                count <= (others => '0');
            elsif wr_en = '1' and rd_en = '0' then
                count <= count + 1;
            elsif wr_en = '0' and rd_en = '1' then
                count <= count - 1;
            end if;
        end if;
    end process;

    -- Read data from RAM (registered output for better timing)
    rd_word <= ram(to_integer(rd_ptr));

    -- Unpack read word
    m_axis_tdata  <= rd_word(DATA_WIDTH - 1 downto 0);
    m_axis_tkeep  <= rd_word(DATA_WIDTH + KEEP_W - 1 downto DATA_WIDTH);
    m_axis_tlast  <= rd_word(DATA_WIDTH + KEEP_W);
    m_axis_tuser  <= rd_word(DATA_WIDTH + KEEP_W + 1 + USER_WIDTH - 1 downto DATA_WIDTH + KEEP_W + 1);
    m_axis_tid    <= rd_word(DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH - 1 downto DATA_WIDTH + KEEP_W + 1 + USER_WIDTH);
    m_axis_tdest  <= rd_word(WORD_W - 1 downto DATA_WIDTH + KEEP_W + 1 + USER_WIDTH + ID_WIDTH);

    m_axis_tvalid <= not empty_i;
    s_axis_tready <= not full_i;

    full  <= full_i;
    empty <= empty_i;
    level <= std_logic_vector(count);

end architecture rtl;
