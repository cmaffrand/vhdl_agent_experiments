-- =============================================================================
-- axis_dwidth_conv.vhd
-- AXI-Stream Data Width Converter.
-- Supports both upsizing (narrow -> wide) and downsizing (wide -> narrow).
--
-- UPSIZING (S_DATA_WIDTH < M_DATA_WIDTH):
--   Accumulates S_DATA_WIDTH-bit beats into an M_DATA_WIDTH-bit output beat.
--   RATIO = M_DATA_WIDTH / S_DATA_WIDTH must be a power of 2.
--   tlast on the last input beat propagates to the output beat.
--
-- DOWNSIZING (S_DATA_WIDTH > M_DATA_WIDTH):
--   Splits an S_DATA_WIDTH-bit input beat into multiple M_DATA_WIDTH-bit output
--   beats.  RATIO = S_DATA_WIDTH / M_DATA_WIDTH must be a power of 2.
--   tlast is propagated on the last output beat of each input beat that has
--   tlast set.
--
-- When S_DATA_WIDTH == M_DATA_WIDTH, the module is a pass-through.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_dwidth_conv is
    generic (
        S_DATA_WIDTH : positive := 8;   -- Input  data width
        M_DATA_WIDTH : positive := 32;  -- Output data width
        USER_WIDTH   : natural  := 1;
        ID_WIDTH     : natural  := 1;
        DEST_WIDTH   : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (narrow/input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(S_DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector((S_DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic_vector(USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master (wide/output) interface
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(M_DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector((M_DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0)
    );
end entity axis_dwidth_conv;

architecture rtl of axis_dwidth_conv is

    -- Determine conversion direction and ratio
    constant UPSIZE : boolean := (M_DATA_WIDTH > S_DATA_WIDTH);

    function compute_ratio return positive is
    begin
        if M_DATA_WIDTH >= S_DATA_WIDTH then
            return M_DATA_WIDTH / S_DATA_WIDTH;
        else
            return S_DATA_WIDTH / M_DATA_WIDTH;
        end if;
    end function compute_ratio;

    constant RATIO  : positive := compute_ratio;

    constant S_KEEP_W : natural := S_DATA_WIDTH / 8;
    constant M_KEEP_W : natural := M_DATA_WIDTH / 8;
    constant CNT_BITS : natural := clog2(RATIO);

    -- Upsize accumulation registers
    signal up_data  : std_logic_vector(M_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal up_keep  : std_logic_vector(M_KEEP_W     - 1 downto 0) := (others => '0');
    signal up_last  : std_logic := '0';
    signal up_user  : std_logic_vector(USER_WIDTH - 1 downto 0)   := (others => '0');
    signal up_id    : std_logic_vector(ID_WIDTH   - 1 downto 0)   := (others => '0');
    signal up_dest  : std_logic_vector(DEST_WIDTH - 1 downto 0)   := (others => '0');
    signal up_count : unsigned(CNT_BITS - 1 downto 0)             := (others => '0');
    signal up_valid : std_logic                                    := '0';

    -- Downsize register (one full wide word)
    signal dn_data  : std_logic_vector(S_DATA_WIDTH - 1 downto 0) := (others => '0');
    signal dn_keep  : std_logic_vector(S_KEEP_W     - 1 downto 0) := (others => '0');
    signal dn_last  : std_logic := '0';
    signal dn_user  : std_logic_vector(USER_WIDTH - 1 downto 0)   := (others => '0');
    signal dn_id    : std_logic_vector(ID_WIDTH   - 1 downto 0)   := (others => '0');
    signal dn_dest  : std_logic_vector(DEST_WIDTH - 1 downto 0)   := (others => '0');
    signal dn_count : unsigned(CNT_BITS - 1 downto 0)             := (others => '0');
    signal dn_valid : std_logic                                    := '0';

begin

    -- =========================================================================
    -- UPSIZING path  (S narrow -> M wide)
    -- =========================================================================
    gen_upsize : if UPSIZE generate

        process (aclk) is
            variable next_count : unsigned(CNT_BITS - 1 downto 0);
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    up_count <= (others => '0');
                    up_valid <= '0';
                    up_last  <= '0';
                else
                    -- Accept input when we can: either no valid out or being consumed
                    if s_axis_tvalid = '1' and (up_valid = '0' or m_axis_tready = '1') then
                        -- Clear accumulator when output is consumed and we start a new one
                        if up_valid = '1' and m_axis_tready = '1' then
                            up_count <= (others => '0');
                        end if;
                        next_count := up_count when not (up_valid = '1' and m_axis_tready = '1')
                                      else (others => '0');

                        -- Slice input data into accumulator position
                        up_data(S_DATA_WIDTH * (to_integer(next_count) + 1) - 1
                                downto S_DATA_WIDTH * to_integer(next_count))
                            <= s_axis_tdata;
                        up_keep(S_KEEP_W * (to_integer(next_count) + 1) - 1
                                downto S_KEEP_W * to_integer(next_count))
                            <= s_axis_tkeep;
                        up_user  <= s_axis_tuser;
                        up_id    <= s_axis_tid;
                        up_dest  <= s_axis_tdest;

                        up_count <= next_count + 1;

                        if s_axis_tlast = '1' or next_count = RATIO - 1 then
                            up_valid <= '1';
                            up_last  <= s_axis_tlast;
                            up_count <= (others => '0');
                        else
                            if up_valid = '1' and m_axis_tready = '1' then
                                up_valid <= '0';
                            end if;
                        end if;
                    elsif up_valid = '1' and m_axis_tready = '1' then
                        up_valid <= '0';
                        up_last  <= '0';
                        up_count <= (others => '0');
                    end if;
                end if;
            end if;
        end process;

        -- Ready when we do not have a full beat waiting or downstream consumes it
        s_axis_tready <= (not up_valid) or m_axis_tready
                         when up_count /= RATIO - 1 else
                         not up_valid or m_axis_tready;

        m_axis_tvalid <= up_valid;
        m_axis_tdata  <= up_data;
        m_axis_tkeep  <= up_keep;
        m_axis_tlast  <= up_last;
        m_axis_tuser  <= up_user;
        m_axis_tid    <= up_id;
        m_axis_tdest  <= up_dest;

    end generate gen_upsize;

    -- =========================================================================
    -- DOWNSIZING path  (S wide -> M narrow)
    -- =========================================================================
    gen_downsize : if not UPSIZE generate

        -- Load new word from input when we are not busy outputting
        process (aclk) is
        begin
            if rising_edge(aclk) then
                if aresetn = '0' then
                    dn_valid <= '0';
                    dn_count <= (others => '0');
                else
                    if dn_valid = '0' and s_axis_tvalid = '1' then
                        -- Load new word
                        dn_data  <= s_axis_tdata;
                        dn_keep  <= s_axis_tkeep;
                        dn_last  <= s_axis_tlast;
                        dn_user  <= s_axis_tuser;
                        dn_id    <= s_axis_tid;
                        dn_dest  <= s_axis_tdest;
                        dn_count <= (others => '0');
                        dn_valid <= '1';
                    elsif dn_valid = '1' and m_axis_tready = '1' then
                        if dn_count = RATIO - 1 then
                            -- Finished outputting all sub-beats
                            dn_valid <= '0';
                            dn_count <= (others => '0');
                        else
                            dn_count <= dn_count + 1;
                        end if;
                    end if;
                end if;
            end if;
        end process;

        -- Accept new input only when idle
        s_axis_tready <= not dn_valid;

        m_axis_tvalid <= dn_valid;
        m_axis_tdata  <= dn_data(M_DATA_WIDTH * (to_integer(dn_count) + 1) - 1
                                 downto M_DATA_WIDTH * to_integer(dn_count));
        m_axis_tkeep  <= dn_keep(M_KEEP_W * (to_integer(dn_count) + 1) - 1
                                 downto M_KEEP_W * to_integer(dn_count));
        m_axis_tlast  <= dn_last when dn_count = RATIO - 1 else '0';
        m_axis_tuser  <= dn_user;
        m_axis_tid    <= dn_id;
        m_axis_tdest  <= dn_dest;

    end generate gen_downsize;

    -- =========================================================================
    -- Pass-through when widths are equal
    -- =========================================================================
    gen_passthrough : if S_DATA_WIDTH = M_DATA_WIDTH generate
        m_axis_tvalid <= s_axis_tvalid;
        s_axis_tready <= m_axis_tready;
        m_axis_tdata  <= s_axis_tdata;
        m_axis_tkeep  <= s_axis_tkeep;
        m_axis_tlast  <= s_axis_tlast;
        m_axis_tuser  <= s_axis_tuser;
        m_axis_tid    <= s_axis_tid;
        m_axis_tdest  <= s_axis_tdest;
    end generate gen_passthrough;

end architecture rtl;
