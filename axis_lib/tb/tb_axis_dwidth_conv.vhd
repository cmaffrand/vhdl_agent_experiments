-- =============================================================================
-- tb_axis_dwidth_conv.vhd
-- Testbench for axis_dwidth_conv – tests both upsize and downsize paths
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_dwidth_conv is
end entity tb_axis_dwidth_conv;

architecture sim of tb_axis_dwidth_conv is

    constant PERIOD : time := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- =========================================================================
    -- Upsize (8->32) signals
    -- =========================================================================
    signal up_s_valid : std_logic := '0';
    signal up_s_ready : std_logic;
    signal up_s_data  : std_logic_vector(7 downto 0)  := (others => '0');
    signal up_s_keep  : std_logic_vector(0 downto 0)  := (others => '1');
    signal up_s_last  : std_logic := '0';
    signal up_s_user  : std_logic_vector(0 downto 0)  := (others => '0');
    signal up_s_id    : std_logic_vector(0 downto 0)  := (others => '0');
    signal up_s_dest  : std_logic_vector(0 downto 0)  := (others => '0');

    signal up_m_valid : std_logic;
    signal up_m_ready : std_logic := '1';
    signal up_m_data  : std_logic_vector(31 downto 0);
    signal up_m_keep  : std_logic_vector(3 downto 0);
    signal up_m_last  : std_logic;
    signal up_m_user  : std_logic_vector(0 downto 0);
    signal up_m_id    : std_logic_vector(0 downto 0);
    signal up_m_dest  : std_logic_vector(0 downto 0);

    -- =========================================================================
    -- Downsize (32->8) signals
    -- =========================================================================
    signal dn_s_valid : std_logic := '0';
    signal dn_s_ready : std_logic;
    signal dn_s_data  : std_logic_vector(31 downto 0) := (others => '0');
    signal dn_s_keep  : std_logic_vector(3 downto 0)  := (others => '1');
    signal dn_s_last  : std_logic := '0';
    signal dn_s_user  : std_logic_vector(0 downto 0)  := (others => '0');
    signal dn_s_id    : std_logic_vector(0 downto 0)  := (others => '0');
    signal dn_s_dest  : std_logic_vector(0 downto 0)  := (others => '0');

    signal dn_m_valid : std_logic;
    signal dn_m_ready : std_logic := '1';
    signal dn_m_data  : std_logic_vector(7 downto 0);
    signal dn_m_keep  : std_logic_vector(0 downto 0);
    signal dn_m_last  : std_logic;
    signal dn_m_user  : std_logic_vector(0 downto 0);
    signal dn_m_id    : std_logic_vector(0 downto 0);
    signal dn_m_dest  : std_logic_vector(0 downto 0);

    signal errors : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    -- Upsizer DUT
    u_upsize : entity work.axis_dwidth_conv
        generic map (S_DATA_WIDTH => 8, M_DATA_WIDTH => 32,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => up_s_valid, s_axis_tready => up_s_ready,
            s_axis_tdata  => up_s_data,  s_axis_tkeep  => up_s_keep,
            s_axis_tlast  => up_s_last,  s_axis_tuser  => up_s_user,
            s_axis_tid    => up_s_id,    s_axis_tdest  => up_s_dest,
            m_axis_tvalid => up_m_valid, m_axis_tready => up_m_ready,
            m_axis_tdata  => up_m_data,  m_axis_tkeep  => up_m_keep,
            m_axis_tlast  => up_m_last,  m_axis_tuser  => up_m_user,
            m_axis_tid    => up_m_id,    m_axis_tdest  => up_m_dest
        );

    -- Downsizer DUT
    u_downsize : entity work.axis_dwidth_conv
        generic map (S_DATA_WIDTH => 32, M_DATA_WIDTH => 8,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => dn_s_valid, s_axis_tready => dn_s_ready,
            s_axis_tdata  => dn_s_data,  s_axis_tkeep  => dn_s_keep,
            s_axis_tlast  => dn_s_last,  s_axis_tuser  => dn_s_user,
            s_axis_tid    => dn_s_id,    s_axis_tdest  => dn_s_dest,
            m_axis_tvalid => dn_m_valid, m_axis_tready => dn_m_ready,
            m_axis_tdata  => dn_m_data,  m_axis_tkeep  => dn_m_keep,
            m_axis_tlast  => dn_m_last,  m_axis_tuser  => dn_m_user,
            m_axis_tid    => dn_m_id,    m_axis_tdest  => dn_m_dest
        );

    stim : process is
        -- Send 4 narrow (8-bit) beats to upsizer
        procedure up_send_beat (data : std_logic_vector(7 downto 0);
                                last : std_logic) is
        begin
            up_s_data  <= data;
            up_s_last  <= last;
            up_s_valid <= '1';
            wait until rising_edge(aclk) and up_s_ready = '1';
            up_s_valid <= '0';
            wait for 1 ns;
        end procedure;

        -- Send one wide (32-bit) beat to downsizer
        procedure dn_send_beat (data : std_logic_vector(31 downto 0);
                                last : std_logic) is
        begin
            dn_s_data  <= data;
            dn_s_last  <= last;
            dn_s_valid <= '1';
            wait until rising_edge(aclk) and dn_s_ready = '1';
            dn_s_valid <= '0';
            wait for 1 ns;
        end procedure;
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait for PERIOD;

        -- =====================================================================
        -- Test Upsizer: send 4 bytes, expect one 32-bit word
        -- =====================================================================
        up_m_ready <= '1';
        up_send_beat(x"01", '0');
        up_send_beat(x"02", '0');
        up_send_beat(x"03", '0');
        up_send_beat(x"04", '1');  -- last beat triggers output

        -- Wait for upsize output
        wait until rising_edge(aclk) and up_m_valid = '1';
        if up_m_data /= x"04030201" then
            report "Upsize data mismatch: got " & to_hstring(up_m_data)
                   & " expected 04030201" severity error;
            errors <= errors + 1;
        end if;
        if up_m_last /= '1' then
            report "Upsize tlast missing" severity error;
            errors <= errors + 1;
        end if;
        wait for PERIOD * 3;

        -- =====================================================================
        -- Test Downsizer: send one 32-bit word, expect 4 bytes
        -- =====================================================================
        dn_m_ready <= '1';
        dn_send_beat(x"DEADBEEF", '1');

        -- Read 4 output bytes from DEADBEEF (little-endian: EF, BE, AD, DE)
        wait until rising_edge(aclk) and dn_m_valid = '1';
        if dn_m_data /= x"EF" then
            report "Downsize byte 0 mismatch: got " & to_hstring(dn_m_data) severity error;
            errors <= errors + 1;
        end if;
        wait until rising_edge(aclk) and dn_m_valid = '1';
        if dn_m_data /= x"BE" then
            report "Downsize byte 1 mismatch: got " & to_hstring(dn_m_data) severity error;
            errors <= errors + 1;
        end if;
        wait until rising_edge(aclk) and dn_m_valid = '1';
        if dn_m_data /= x"AD" then
            report "Downsize byte 2 mismatch: got " & to_hstring(dn_m_data) severity error;
            errors <= errors + 1;
        end if;
        wait until rising_edge(aclk) and dn_m_valid = '1';
        if dn_m_data /= x"DE" then
            report "Downsize byte 3 mismatch: got " & to_hstring(dn_m_data) severity error;
            errors <= errors + 1;
        end if;
        if dn_m_last /= '1' then
            report "Downsize tlast missing on last byte" severity error;
            errors <= errors + 1;
        end if;

        wait for PERIOD * 5;

        if errors = 0 then
            report "tb_axis_dwidth_conv: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_dwidth_conv: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
