-- =============================================================================
-- tb_axis_joiner_splitter.vhd
-- Testbench for axis_joiner and axis_splitter
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_joiner_splitter is
end entity tb_axis_joiner_splitter;

architecture sim of tb_axis_joiner_splitter is

    constant DATA_W : positive := 8;
    constant N      : positive := 2;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- =========================================================================
    -- Joiner signals (2 inputs, 1 wide output)
    -- =========================================================================
    signal join_s_valid : std_logic_vector(N-1 downto 0) := (others => '0');
    signal join_s_ready : std_logic_vector(N-1 downto 0);
    signal join_s_data  : std_logic_vector(N*DATA_W-1 downto 0) := (others => '0');
    signal join_s_keep  : std_logic_vector(N-1 downto 0) := (others => '1');
    signal join_s_last  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal join_s_user  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal join_s_id    : std_logic_vector(N-1 downto 0) := (others => '0');
    signal join_s_dest  : std_logic_vector(N-1 downto 0) := (others => '0');

    signal join_m_valid : std_logic;
    signal join_m_ready : std_logic := '1';
    signal join_m_data  : std_logic_vector(N*DATA_W-1 downto 0);
    signal join_m_keep  : std_logic_vector(N-1 downto 0);
    signal join_m_last  : std_logic;
    signal join_m_user  : std_logic_vector(0 downto 0);
    signal join_m_id    : std_logic_vector(0 downto 0);
    signal join_m_dest  : std_logic_vector(0 downto 0);

    -- =========================================================================
    -- Splitter signals (1 input -> 2 outputs)
    -- =========================================================================
    signal spl_s_valid : std_logic := '0';
    signal spl_s_ready : std_logic;
    signal spl_s_data  : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal spl_s_keep  : std_logic_vector(0 downto 0) := (others => '1');
    signal spl_s_last  : std_logic := '0';
    signal spl_s_user  : std_logic_vector(0 downto 0) := (others => '0');
    signal spl_s_id    : std_logic_vector(0 downto 0) := (others => '0');
    signal spl_s_dest  : std_logic_vector(0 downto 0) := (others => '0');

    signal spl_a_valid, spl_b_valid : std_logic;
    signal spl_a_ready, spl_b_ready : std_logic := '1';
    signal spl_a_data,  spl_b_data  : std_logic_vector(DATA_W-1 downto 0);
    signal spl_a_keep,  spl_b_keep  : std_logic_vector(0 downto 0);
    signal spl_a_last,  spl_b_last  : std_logic;
    signal spl_a_user,  spl_b_user  : std_logic_vector(0 downto 0);
    signal spl_a_id,    spl_b_id    : std_logic_vector(0 downto 0);
    signal spl_a_dest,  spl_b_dest  : std_logic_vector(0 downto 0);

    signal errors : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    -- Joiner DUT (2 inputs)
    u_joiner : entity work.axis_joiner
        generic map (N_PORTS => N, DATA_WIDTH => DATA_W,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => join_s_valid, s_axis_tready => join_s_ready,
            s_axis_tdata  => join_s_data,  s_axis_tkeep  => join_s_keep,
            s_axis_tlast  => join_s_last,  s_axis_tuser  => join_s_user,
            s_axis_tid    => join_s_id,    s_axis_tdest  => join_s_dest,
            m_axis_tvalid => join_m_valid, m_axis_tready => join_m_ready,
            m_axis_tdata  => join_m_data,  m_axis_tkeep  => join_m_keep,
            m_axis_tlast  => join_m_last,  m_axis_tuser  => join_m_user,
            m_axis_tid    => join_m_id,    m_axis_tdest  => join_m_dest
        );

    -- Splitter DUT (SPLIT_BEAT=2 -> 2 beats to output A, rest to output B)
    u_splitter : entity work.axis_splitter
        generic map (DATA_WIDTH => DATA_W,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1,
                     SPLIT_BEAT => 2)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => spl_s_valid, s_axis_tready => spl_s_ready,
            s_axis_tdata  => spl_s_data,  s_axis_tkeep  => spl_s_keep,
            s_axis_tlast  => spl_s_last,  s_axis_tuser  => spl_s_user,
            s_axis_tid    => spl_s_id,    s_axis_tdest  => spl_s_dest,
            m_axis_a_tvalid => spl_a_valid, m_axis_a_tready => spl_a_ready,
            m_axis_a_tdata  => spl_a_data,  m_axis_a_tkeep  => spl_a_keep,
            m_axis_a_tlast  => spl_a_last,  m_axis_a_tuser  => spl_a_user,
            m_axis_a_tid    => spl_a_id,    m_axis_a_tdest  => spl_a_dest,
            m_axis_b_tvalid => spl_b_valid, m_axis_b_tready => spl_b_ready,
            m_axis_b_tdata  => spl_b_data,  m_axis_b_tkeep  => spl_b_keep,
            m_axis_b_tlast  => spl_b_last,  m_axis_b_tuser  => spl_b_user,
            m_axis_b_tid    => spl_b_id,    m_axis_b_tdest  => spl_b_dest
        );

    stim : process is
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        wait for PERIOD;

        -- =====================================================================
        -- Joiner test: present data on both ports simultaneously
        -- =====================================================================
        join_m_ready <= '1';

        -- Beat 1: both ports valid, data = {0xBB, 0xAA}
        join_s_data(DATA_W-1 downto 0)       <= x"AA";   -- port 0
        join_s_data(2*DATA_W-1 downto DATA_W) <= x"BB";  -- port 1
        join_s_last  <= "11";
        join_s_valid <= "11";  -- both valid simultaneously
        wait until rising_edge(aclk) and join_m_valid = '1' and join_m_ready = '1';
        if join_m_data(DATA_W-1 downto 0) /= x"AA" or
           join_m_data(2*DATA_W-1 downto DATA_W) /= x"BB" then
            report "Joiner data mismatch" severity error;
            errors <= errors + 1;
        end if;
        join_s_valid <= "00";
        wait for PERIOD * 3;

        -- =====================================================================
        -- Splitter test: send 5-beat packet; beats 0-1 go to A, 2-4 go to B
        -- =====================================================================
        spl_a_ready <= '1';
        spl_b_ready <= '1';

        for i in 0 to 4 loop
            spl_s_data  <= std_logic_vector(to_unsigned(i + 1, DATA_W));
            spl_s_last  <= '1' when i = 4 else '0';
            spl_s_valid <= '1';
            wait until rising_edge(aclk) and spl_s_ready = '1';
        end loop;
        spl_s_valid <= '0';
        wait for PERIOD * 5;

        if errors = 0 then
            report "tb_axis_joiner_splitter: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_joiner_splitter: " & integer'image(errors) & " ERRORS"
                   severity failure;
        end if;
        wait;
    end process;

end architecture sim;
