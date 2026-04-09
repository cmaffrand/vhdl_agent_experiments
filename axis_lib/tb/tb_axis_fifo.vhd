-- =============================================================================
-- tb_axis_fifo.vhd
-- Testbench for axis_fifo (and implicitly axis_fifo_dp)
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_fifo is
end entity tb_axis_fifo;

architecture sim of tb_axis_fifo is

    constant DATA_W : positive := 8;
    constant DEPTH  : positive := 8;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- FIFO interface
    signal full_s, empty_s : std_logic;
    signal level_s : std_logic_vector(3 downto 0);  -- clog2(8+1)=4

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

    dut : entity work.axis_fifo
        generic map (
            DATA_WIDTH => DATA_W, DEPTH => DEPTH,
            KEEP_ENABLE => 1, LAST_ENABLE => 1,
            USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1
        )
        port map (
            aclk => aclk, aresetn => aresetn,
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
            wait for 1 ns;  -- delta
        end procedure;

        procedure read_beat (expected : std_logic_vector(DATA_W-1 downto 0)) is
        begin
            m_ready <= '1';
            wait until rising_edge(aclk) and m_valid = '1';
            if m_data /= expected then
                report "FIFO read mismatch: got " & to_hstring(m_data) &
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

        -- Test 1: Write 4 beats, then read them back in order
        for i in 0 to 3 loop
            write_beat(std_logic_vector(to_unsigned(i * 16#11#, DATA_W)), '0');
        end loop;
        write_beat(x"44", '1');  -- last beat

        for i in 0 to 3 loop
            read_beat(std_logic_vector(to_unsigned(i * 16#11#, DATA_W)));
        end loop;
        read_beat(x"44");

        wait for PERIOD * 5;

        -- Test 2: Fill to near-full then drain
        for i in 0 to DEPTH - 2 loop
            if i = DEPTH - 2 then
                write_beat(std_logic_vector(to_unsigned(i, DATA_W)), '1');
            else
                write_beat(std_logic_vector(to_unsigned(i, DATA_W)), '0');
            end if;
        end loop;

        m_ready <= '1';
        for i in 0 to DEPTH - 2 loop
            wait until rising_edge(aclk) and m_valid = '1';
        end loop;
        m_ready <= '0';

        wait for PERIOD * 5;

        -- Test 3: FIFO empty check
        if empty_s /= '1' then
            report "FIFO should be empty" severity error;
            errors <= errors + 1;
        end if;

        if errors = 0 then
            report "tb_axis_fifo: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_fifo: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
