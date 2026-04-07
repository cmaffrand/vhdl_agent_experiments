-- =============================================================================
-- axis_frame_len.vhd
-- AXI-Stream Frame Length Checker.
-- Counts the byte-valid beats in each frame (from start to tlast).
-- Asserts err_short_o when frame is shorter than MIN_FRAME_BYTES.
-- Asserts err_long_o  when frame is longer  than MAX_FRAME_BYTES.
-- The error flags are valid on the same cycle as the tlast is accepted.
-- frame_len_o carries the frame length (in beats, not necessarily bytes).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_frame_len is
    generic (
        DATA_WIDTH      : positive := 8;
        USER_WIDTH      : natural  := 1;
        ID_WIDTH        : natural  := 1;
        DEST_WIDTH      : natural  := 1;
        MIN_FRAME_BYTES : natural  := 64;   -- 0 = no minimum check
        MAX_FRAME_BYTES : natural  := 1518; -- 0 = no maximum check
        LEN_BITS        : positive := 16    -- bits for frame length counter
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

        -- Master (output) interface -- data passes through unchanged
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Status (valid when m_axis_tlast and m_axis_tvalid and m_axis_tready)
        frame_len_o : out std_logic_vector(LEN_BITS - 1 downto 0);
        err_short_o : out std_logic;
        err_long_o  : out std_logic
    );
end entity axis_frame_len;

architecture rtl of axis_frame_len is

    constant KEEP_W : natural := DATA_WIDTH / 8;

    -- Count bytes by summing tkeep bits each beat
    function count_ones(v : std_logic_vector) return unsigned is
        variable s : unsigned(clog2(v'length + 1) - 1 downto 0) := (others => '0');
    begin
        for i in v'range loop
            if v(i) = '1' then
                s := s + 1;
            end if;
        end loop;
        return s;
    end function count_ones;

    signal byte_cnt  : unsigned(LEN_BITS - 1 downto 0) := (others => '0');
    signal accepted  : std_logic;

begin

    accepted <= s_axis_tvalid and m_axis_tready;

    -- Byte counter
    process (aclk) is
        variable keep_ones : unsigned(clog2(KEEP_W + 1) - 1 downto 0);
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                byte_cnt <= (others => '0');
            elsif accepted = '1' then
                keep_ones := count_ones(s_axis_tkeep);
                if s_axis_tlast = '1' then
                    byte_cnt <= (others => '0');
                else
                    byte_cnt <= byte_cnt + keep_ones;
                end if;
            end if;
        end if;
    end process;

    -- Error flags and frame length output (combinatorial, valid on last beat)
    process (all) is
        variable final_len  : unsigned(LEN_BITS - 1 downto 0);
        variable keep_ones  : unsigned(clog2(KEEP_W + 1) - 1 downto 0);
    begin
        keep_ones  := count_ones(s_axis_tkeep);
        final_len  := byte_cnt + keep_ones;

        frame_len_o <= std_logic_vector(final_len);

        err_short_o <= '0';
        err_long_o  <= '0';

        if accepted = '1' and s_axis_tlast = '1' then
            if MIN_FRAME_BYTES > 0 and final_len < MIN_FRAME_BYTES then
                err_short_o <= '1';
            end if;
            if MAX_FRAME_BYTES > 0 and final_len > MAX_FRAME_BYTES then
                err_long_o <= '1';
            end if;
        end if;
    end process;

    -- Pass-through data path
    m_axis_tvalid <= s_axis_tvalid;
    s_axis_tready <= m_axis_tready;
    m_axis_tdata  <= s_axis_tdata;
    m_axis_tkeep  <= s_axis_tkeep;
    m_axis_tlast  <= s_axis_tlast;
    m_axis_tuser  <= s_axis_tuser;
    m_axis_tid    <= s_axis_tid;
    m_axis_tdest  <= s_axis_tdest;

end architecture rtl;
