-- =============================================================================
-- tb_axis_broadcaster.vhd
-- Testbench for axis_broadcaster
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_broadcaster is
end entity tb_axis_broadcaster;

architecture sim of tb_axis_broadcaster is

    constant DATA_W : positive := 8;
    constant N      : positive := 3;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    signal s_valid : std_logic := '0';
    signal s_ready : std_logic;
    signal s_data  : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal s_keep  : std_logic_vector(0 downto 0) := (others => '1');
    signal s_last  : std_logic := '0';
    signal s_user  : std_logic_vector(0 downto 0) := (others => '0');
    signal s_id    : std_logic_vector(0 downto 0) := (others => '0');
    signal s_dest  : std_logic_vector(0 downto 0) := (others => '0');

    signal m_valid : std_logic_vector(N-1 downto 0);
    signal m_ready : std_logic_vector(N-1 downto 0) := (others => '1');
    signal m_data  : std_logic_vector(N*DATA_W-1 downto 0);
    signal m_keep  : std_logic_vector(N*(DATA_W/8)-1 downto 0);
    signal m_last  : std_logic_vector(N-1 downto 0);
    signal m_user  : std_logic_vector(N-1 downto 0);
    signal m_id    : std_logic_vector(N-1 downto 0);
    signal m_dest  : std_logic_vector(N-1 downto 0);

    signal errors : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    dut : entity work.axis_broadcaster
        generic map (N_PORTS => N, DATA_WIDTH => DATA_W,
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
            wait for 1 ns;
        end procedure;

        procedure check_all (expected : std_logic_vector(DATA_W-1 downto 0)) is
        begin
            for i in 0 to N-1 loop
                if m_valid(i) = '1' then
                    if m_data((i+1)*DATA_W-1 downto i*DATA_W) /= expected then
                        report "Broadcaster port " & integer'image(i) &
                               " data mismatch" severity error;
                        errors <= errors + 1;
                    end if;
                end if;
            end loop;
        end procedure;
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait for PERIOD;

        -- Test 1: All outputs ready – send 2 beats
        m_ready <= (others => '1');
        send_beat(x"AA", '0');
        -- Verify all 3 ports receive the same data
        wait for PERIOD;
        send_beat(x"BB", '1');
        wait for PERIOD * 3;

        -- Test 2: One output stalls – port 1 not ready
        m_ready <= (others => '1');
        m_ready(1) <= '0';

        s_data  <= x"CC";
        s_last  <= '0';
        s_valid <= '1';
        -- Input should NOT be consumed since port 1 is not ready
        wait for PERIOD * 2;
        if s_ready = '1' then
            report "Expected stall when port 1 not ready" severity error;
            errors <= errors + 1;
        end if;
        -- Release port 1
        m_ready(1) <= '1';
        wait until rising_edge(aclk) and s_ready = '1';
        -- Check all ports got the data
        check_all(x"CC");
        s_valid <= '0';
        wait for PERIOD * 5;

        if errors = 0 then
            report "tb_axis_broadcaster: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_broadcaster: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
