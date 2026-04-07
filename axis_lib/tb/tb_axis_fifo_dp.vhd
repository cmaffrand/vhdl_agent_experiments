-- =============================================================================
-- tb_axis_fifo_dp.vhd
-- Testbench for axis_fifo_dp (FIFO with drop-packet)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_fifo_dp is
end entity tb_axis_fifo_dp;

architecture sim of tb_axis_fifo_dp is

    constant DATA_W : positive := 8;
    constant DEPTH  : positive := 32;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    signal commit_i : std_logic := '0';
    signal drop_i   : std_logic := '0';

    signal full_s, empty_s : std_logic;
    signal level_s : std_logic_vector(5 downto 0);  -- clog2(32+1)=6

    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_data  : std_logic_vector(DATA_W - 1 downto 0) := (others => '0');
    signal s_keep  : std_logic_vector(0 downto 0) := (others => '1');
    signal s_last  : std_logic := '0';
    signal s_user  : std_logic_vector(0 downto 0) := (others => '0');
    signal s_id    : std_logic_vector(0 downto 0) := (others => '0');
    signal s_dest  : std_logic_vector(0 downto 0) := (others => '0');

    signal m_valid : std_logic;
    signal m_ready : std_logic := '0';
    signal m_data  : std_logic_vector(DATA_W - 1 downto 0);
    signal m_keep  : std_logic_vector(0 downto 0);
    signal m_last  : std_logic;
    signal m_user  : std_logic_vector(0 downto 0);
    signal m_id    : std_logic_vector(0 downto 0);
    signal m_dest  : std_logic_vector(0 downto 0);

    signal errors  : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    dut : entity work.axis_fifo_dp
        generic map (
            DATA_WIDTH => DATA_W, DEPTH => DEPTH,
            KEEP_ENABLE => 1, LAST_ENABLE => 1,
            USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1,
            AUTO_COMMIT => 1
        )
        port map (
            aclk => aclk, aresetn => aresetn,
            commit_i => commit_i, drop_i => drop_i,
            full  => full_s, empty => empty_s, level => level_s,
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
        procedure write_beat (data : std_logic_vector(DATA_W-1 downto 0);
                              last : std_logic) is
        begin
            s_data  <= data;
            s_last  <= last;
            s_valid <= '1';
            wait until rising_edge(aclk) and s_ready = '1';
            s_valid <= '0';
            wait for 1 ns;
        end procedure;

        procedure read_beat (expected : std_logic_vector(DATA_W-1 downto 0)) is
        begin
            m_ready <= '1';
            wait until rising_edge(aclk) and m_valid = '1';
            if m_data /= expected then
                report "DP-FIFO read mismatch: got " & to_hstring(m_data) &
                       " expected " & to_hstring(expected) severity error;
                errors <= errors + 1;
            end if;
            m_ready <= '0';
        end procedure;
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait for PERIOD;

        -- Test 1: Auto-commit – write a packet, verify it appears on output
        write_beat(x"AA", '0');
        write_beat(x"BB", '0');
        write_beat(x"CC", '1');  -- tlast -> auto-commit
        wait for PERIOD * 2;

        read_beat(x"AA");
        read_beat(x"BB");
        read_beat(x"CC");
        wait for PERIOD * 5;

        -- Test 2: Drop – write a packet with drop signal on tlast
        write_beat(x"11", '0');
        write_beat(x"22", '0');
        drop_i <= '1';
        write_beat(x"33", '1');  -- tlast with drop -> packet discarded
        drop_i <= '0';
        wait for PERIOD * 3;

        -- Verify FIFO empty (dropped packet should not appear)
        if empty_s /= '1' then
            report "FIFO should be empty after drop" severity error;
            errors <= errors + 1;
        end if;

        -- Test 3: Write a valid packet after drop
        write_beat(x"DE", '0');
        write_beat(x"AD", '1');
        wait for PERIOD * 2;
        read_beat(x"DE");
        read_beat(x"AD");

        wait for PERIOD * 5;

        if errors = 0 then
            report "tb_axis_fifo_dp: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_fifo_dp: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
