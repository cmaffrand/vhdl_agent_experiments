-- =============================================================================
-- axis_error_inj.vhd
-- AXI-Stream Error Injection Module.
-- Allows controlled injection of various fault types into an AXI-Stream:
--   - Bit-flip errors   (corrupt one or more bits in a beat)
--   - Packet drops      (swallow a complete packet)
--   - Duplicate packets (send the same packet twice)
--   - tlast insertion   (prematurely end a packet)
--   - tkeep corruption  (mark bytes as invalid)
--
-- Error injection is controlled via a simple register interface:
--   err_type_i  : type of error to inject (see constants below)
--   err_beat_i  : beat number within a packet to affect (0 = all)
--   err_mask_i  : bit mask applied when injecting bit-flip errors
--   err_inject_i: pulse to trigger one error injection
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_error_inj is
    generic (
        DATA_WIDTH : positive := 8;
        USER_WIDTH : natural  := 1;
        ID_WIDTH   : natural  := 1;
        DEST_WIDTH : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Error injection control
        -- err_type_i: 0=none, 1=bit-flip, 2=drop packet, 3=duplicate, 4=early-last, 5=keep-corrupt
        err_type_i   : in  std_logic_vector(2 downto 0) := (others => '0');
        err_beat_i   : in  std_logic_vector(7 downto 0) := (others => '0');
        err_mask_i   : in  std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
        err_inject_i : in  std_logic := '0';  -- Pulse to arm one error injection

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
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Status
        err_pending_o : out std_logic   -- '1' when an error is armed but not yet injected
    );
end entity axis_error_inj;

architecture rtl of axis_error_inj is

    -- Error type constants
    constant ERR_NONE     : std_logic_vector(2 downto 0) := "000";
    constant ERR_BITFLIP  : std_logic_vector(2 downto 0) := "001";
    constant ERR_DROP     : std_logic_vector(2 downto 0) := "010";
    constant ERR_DUP      : std_logic_vector(2 downto 0) := "011";
    constant ERR_EARLAST  : std_logic_vector(2 downto 0) := "100";
    constant ERR_KEEP_COR : std_logic_vector(2 downto 0) := "101";

    -- Latched error parameters
    signal err_armed  : std_logic := '0';
    signal err_type_r : std_logic_vector(2 downto 0) := (others => '0');
    signal err_beat_r : std_logic_vector(7 downto 0) := (others => '0');
    signal err_mask_r : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');

    signal beat_cnt   : unsigned(7 downto 0) := (others => '0');
    signal pkt_accept : std_logic;  -- beat is accepted this cycle

    -- Duplicate packet buffer
    signal dup_buf_valid : std_logic := '0';
    signal dup_buf_data  : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal dup_buf_keep  : std_logic_vector((DATA_WIDTH/8) - 1 downto 0) := (others => '0');
    signal dup_buf_last  : std_logic := '0';
    signal dup_buf_user  : std_logic_vector(USER_WIDTH - 1 downto 0)  := (others => '0');
    signal dup_buf_id    : std_logic_vector(ID_WIDTH   - 1 downto 0)  := (others => '0');
    signal dup_buf_dest  : std_logic_vector(DEST_WIDTH - 1 downto 0)  := (others => '0');
    signal dup_sending   : std_logic := '0';

    signal drop_active : std_logic := '0';

begin

    pkt_accept <= s_axis_tvalid and s_axis_tready;

    -- Arm error on inject pulse
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                err_armed  <= '0';
            elsif err_inject_i = '1' and err_armed = '0' then
                err_armed  <= '1';
                err_type_r <= err_type_i;
                err_beat_r <= err_beat_i;
                err_mask_r <= err_mask_i;
            elsif err_armed = '1' and s_axis_tvalid = '1' and s_axis_tlast = '1'
                  and m_axis_tready = '1' then
                err_armed <= '0';
            end if;
        end if;
    end process;

    err_pending_o <= err_armed;

    -- Beat counter within packet
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                beat_cnt <= (others => '0');
            elsif s_axis_tvalid = '1' and s_axis_tready = '1' then
                if s_axis_tlast = '1' then
                    beat_cnt <= (others => '0');
                else
                    beat_cnt <= beat_cnt + 1;
                end if;
            end if;
        end if;
    end process;

    -- Drop logic: when error type is DROP, swallow the entire packet
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                drop_active <= '0';
            elsif err_armed = '1' and err_type_r = ERR_DROP then
                if s_axis_tvalid = '1' and s_axis_tready = '1' then
                    if s_axis_tlast = '1' then
                        drop_active <= '0';
                    else
                        drop_active <= '1';
                    end if;
                end if;
            else
                drop_active <= '0';
            end if;
        end if;
    end process;

    -- Output logic
    process (all) is
        variable beat_match : boolean;
    begin
        beat_match := (unsigned(err_beat_r) = 0) or (beat_cnt = unsigned(err_beat_r));

        -- Default: pass through
        m_axis_tvalid <= s_axis_tvalid;
        s_axis_tready <= m_axis_tready;
        m_axis_tdata  <= s_axis_tdata;
        m_axis_tkeep  <= s_axis_tkeep;
        m_axis_tlast  <= s_axis_tlast;
        m_axis_tuser  <= s_axis_tuser;
        m_axis_tid    <= s_axis_tid;
        m_axis_tdest  <= s_axis_tdest;

        if err_armed = '1' then
            case err_type_r is
                when ERR_BITFLIP =>
                    if beat_match then
                        m_axis_tdata <= s_axis_tdata xor err_mask_r;
                    end if;

                when ERR_DROP =>
                    -- Swallow data: accept from slave but do not present to master
                    s_axis_tready <= '1';
                    m_axis_tvalid <= '0';

                when ERR_EARLAST =>
                    if beat_match then
                        m_axis_tlast <= '1';
                    end if;

                when ERR_KEEP_COR =>
                    if beat_match then
                        m_axis_tkeep <= (others => '0');
                    end if;

                when others =>
                    null;
            end case;
        end if;
    end process;

end architecture rtl;
