-- =============================================================================
-- tb_axis_buffer.vhd
-- Testbench for axis_buffer
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_buffer is
end entity tb_axis_buffer;

architecture sim of tb_axis_buffer is

    constant DATA_W : positive := 8;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_data  : std_logic_vector(DATA_W - 1 downto 0) := (others => '0');
    signal s_keep  : std_logic_vector(0 downto 0) := (others => '1');
    signal s_last  : std_logic := '0';
    signal s_user  : std_logic_vector(0 downto 0) := (others => '0');
    signal s_id    : std_logic_vector(0 downto 0) := (others => '0');
    signal s_dest  : std_logic_vector(0 downto 0) := (others => '0');

    signal m_valid : std_logic;
    signal m_ready : std_logic := '1';
    signal m_data  : std_logic_vector(DATA_W - 1 downto 0);
    signal m_keep  : std_logic_vector(0 downto 0);
    signal m_last  : std_logic;
    signal m_user  : std_logic_vector(0 downto 0);
    signal m_id    : std_logic_vector(0 downto 0);
    signal m_dest  : std_logic_vector(0 downto 0);

    signal errors  : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    dut : entity work.axis_buffer
        generic map (DATA_WIDTH => DATA_W, KEEP_ENABLE => 1, LAST_ENABLE => 1,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => s_valid, s_axis_tready => s_ready,
            s_axis_tdata  => s_data,  s_axis_tkeep  => s_keep,
            s_axis_tlast  => s_last,  s_axis_tuser  => s_user,
            s_axis_tid    => s_id,    s_axis_tdest  => s_dest,
            m_axis_tvalid => m_valid, m_axis_tready => m_ready,
            m_axis_tdata  => m_data,  m_axis_tkeep  => m_keep,
            m_axis_tlast  => m_last,  m_axis_tuser  => m_user,
            m_axis_tid    => m_id,    m_axis_tdest  => m_dest
        );

    stim : process is
        procedure send_beat (data : std_logic_vector(DATA_W-1 downto 0);
                             last : std_logic) is
        begin
            s_data  <= data;
            s_last  <= last;
            s_valid <= '1';
            wait until rising_edge(aclk) and s_ready = '1';
            s_valid <= '0';
        end procedure;

        procedure check_beat (expected_data : std_logic_vector(DATA_W-1 downto 0);
                              expected_last : std_logic) is
        begin
            m_ready <= '1';
            wait until rising_edge(aclk) and m_valid = '1';
            if m_data /= expected_data then
                report "DATA mismatch: got " & to_hstring(m_data) &
                       " expected " & to_hstring(expected_data) severity error;
                errors <= errors + 1;
            end if;
            if m_last /= expected_last then
                report "LAST mismatch" severity error;
                errors <= errors + 1;
            end if;
        end procedure;
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait for PERIOD;

        -- Test 1: Simple pass-through (m_ready always high)
        m_ready <= '1';
        send_beat(x"AA", '0');
        wait for PERIOD;
        send_beat(x"BB", '1');
        wait for PERIOD * 3;

        -- Test 2: Back-pressure – hold m_ready low while sending
        m_ready <= '0';
        s_data  <= x"CC";
        s_last  <= '0';
        s_valid <= '1';
        wait for PERIOD * 2;
        -- Now release ready
        m_ready <= '1';
        wait until rising_edge(aclk) and m_valid = '1' and m_ready = '1';
        if m_data /= x"CC" then
            report "Back-pressure data mismatch" severity error;
            errors <= errors + 1;
        end if;
        s_valid <= '0';
        wait for PERIOD * 5;

        -- Report result
        if errors = 0 then
            report "tb_axis_buffer: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_buffer: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
