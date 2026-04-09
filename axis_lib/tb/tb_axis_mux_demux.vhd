-- =============================================================================
-- tb_axis_mux_demux.vhd
-- Testbench for axis_mux and axis_demux
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_mux_demux is
end entity tb_axis_mux_demux;

architecture sim of tb_axis_mux_demux is

    constant DATA_W : positive := 8;
    constant N      : positive := 2;
    constant PERIOD : time     := 10 ns;

    signal aclk    : std_logic := '0';
    signal aresetn : std_logic := '0';

    -- MUX inputs (2 ports)
    signal mux_s_valid : std_logic_vector(N-1 downto 0) := (others => '0');
    signal mux_s_ready : std_logic_vector(N-1 downto 0);
    signal mux_s_data  : std_logic_vector(N*DATA_W-1 downto 0) := (others => '0');
    signal mux_s_keep  : std_logic_vector(N*(DATA_W/8)-1 downto 0) := (others => '1');
    signal mux_s_last  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal mux_s_user  : std_logic_vector(N-1 downto 0) := (others => '0');
    signal mux_s_id    : std_logic_vector(N-1 downto 0) := (others => '0');
    signal mux_s_dest  : std_logic_vector(N-1 downto 0) := (others => '0');

    -- MUX output
    signal mux_m_valid : std_logic;
    signal mux_m_ready : std_logic := '1';
    signal mux_m_data  : std_logic_vector(DATA_W-1 downto 0);
    signal mux_m_keep  : std_logic_vector(0 downto 0);
    signal mux_m_last  : std_logic;
    signal mux_m_user  : std_logic_vector(0 downto 0);
    signal mux_m_id    : std_logic_vector(0 downto 0);
    signal mux_m_dest  : std_logic_vector(0 downto 0);

    -- DEMUX input
    signal dmx_s_valid : std_logic := '0';
    signal dmx_s_ready : std_logic;
    signal dmx_s_data  : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal dmx_s_keep  : std_logic_vector(0 downto 0) := (others => '1');
    signal dmx_s_last  : std_logic := '0';
    signal dmx_s_user  : std_logic_vector(0 downto 0) := (others => '0');
    signal dmx_s_id    : std_logic_vector(0 downto 0) := (others => '0');
    signal dmx_s_dest  : std_logic_vector(0 downto 0) := (others => '0');

    -- DEMUX outputs (2 ports)
    signal dmx_m_valid : std_logic_vector(N-1 downto 0);
    signal dmx_m_ready : std_logic_vector(N-1 downto 0) := (others => '1');
    signal dmx_m_data  : std_logic_vector(N*DATA_W-1 downto 0);
    signal dmx_m_keep  : std_logic_vector(N*(DATA_W/8)-1 downto 0);
    signal dmx_m_last  : std_logic_vector(N-1 downto 0);
    signal dmx_m_user  : std_logic_vector(N-1 downto 0);
    signal dmx_m_id    : std_logic_vector(N-1 downto 0);
    signal dmx_m_dest  : std_logic_vector(N-1 downto 0);

    signal errors : natural := 0;

    -- Counters/capture for monitors
    signal mux_beats_rx : natural := 0;
    signal dmx0_data_rx : std_logic_vector(DATA_W-1 downto 0) := (others => '0');
    signal dmx1_data_rx : std_logic_vector(DATA_W-1 downto 0) := (others => '0');

begin

    aclk <= not aclk after PERIOD / 2;

    -- MUX DUT
    u_mux : entity work.axis_mux
        generic map (N_PORTS => N, DATA_WIDTH => DATA_W,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1, ARB_TYPE => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => mux_s_valid, s_axis_tready => mux_s_ready,
            s_axis_tdata  => mux_s_data,  s_axis_tkeep  => mux_s_keep,
            s_axis_tlast  => mux_s_last,  s_axis_tuser  => mux_s_user,
            s_axis_tid    => mux_s_id,    s_axis_tdest  => mux_s_dest,
            m_axis_tvalid => mux_m_valid, m_axis_tready => mux_m_ready,
            m_axis_tdata  => mux_m_data,  m_axis_tkeep  => mux_m_keep,
            m_axis_tlast  => mux_m_last,  m_axis_tuser  => mux_m_user,
            m_axis_tid    => mux_m_id,    m_axis_tdest  => mux_m_dest
        );

    -- DEMUX DUT (using tdest for routing)
    u_demux : entity work.axis_demux
        generic map (N_PORTS => N, DATA_WIDTH => DATA_W,
                     USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1, USE_TDEST => 1)
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => dmx_s_valid, s_axis_tready => dmx_s_ready,
            s_axis_tdata  => dmx_s_data,  s_axis_tkeep  => dmx_s_keep,
            s_axis_tlast  => dmx_s_last,  s_axis_tuser  => dmx_s_user,
            s_axis_tid    => dmx_s_id,    s_axis_tdest  => dmx_s_dest,
            m_axis_tvalid => dmx_m_valid, m_axis_tready => dmx_m_ready,
            m_axis_tdata  => dmx_m_data,  m_axis_tkeep  => dmx_m_keep,
            m_axis_tlast  => dmx_m_last,  m_axis_tuser  => dmx_m_user,
            m_axis_tid    => dmx_m_id,    m_axis_tdest  => dmx_m_dest
        );

    -- Count MUX output beats
    mux_mon : process (aclk) is
    begin
        if rising_edge(aclk) then
            if mux_m_valid = '1' and mux_m_ready = '1' then
                mux_beats_rx <= mux_beats_rx + 1;
            end if;
        end if;
    end process;

    -- Capture DEMUX last data per port
    dmx_mon : process (aclk) is
    begin
        if rising_edge(aclk) then
            if dmx_m_valid(0) = '1' and dmx_m_ready(0) = '1' then
                dmx0_data_rx <= dmx_m_data(DATA_W-1 downto 0);
            end if;
            if dmx_m_valid(1) = '1' and dmx_m_ready(1) = '1' then
                dmx1_data_rx <= dmx_m_data(2*DATA_W-1 downto DATA_W);
            end if;
        end if;
    end process;

    stim : process is
        procedure mux_send_beat (port_num : natural;
                                 data     : std_logic_vector(DATA_W-1 downto 0);
                                 last     : std_logic) is
        begin
            mux_s_data(DATA_W*(port_num+1)-1 downto DATA_W*port_num) <= data;
            mux_s_last(port_num)  <= last;
            mux_s_valid(port_num) <= '1';
            wait until rising_edge(aclk) and mux_s_ready(port_num) = '1';
            mux_s_valid(port_num) <= '0';
            mux_s_last(port_num)  <= '0';
            wait for 1 ns;
        end procedure;

        procedure dmx_send_beat (dest : std_logic_vector(0 downto 0);
                                 data : std_logic_vector(DATA_W-1 downto 0);
                                 last : std_logic) is
        begin
            dmx_s_data  <= data;
            dmx_s_dest  <= dest;
            dmx_s_last  <= last;
            dmx_s_valid <= '1';
            wait until rising_edge(aclk) and dmx_s_ready = '1';
            dmx_s_valid <= '0';
            dmx_s_last  <= '0';
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
        -- MUX test: 2-beat packet on port 0, then 1-beat packet on port 1
        -- Expect 3 total output beats
        -- =====================================================================
        mux_m_ready <= '1';
        mux_send_beat(0, x"A0", '0');
        mux_send_beat(0, x"A1", '1');
        -- Wait for MUX to release grant before sending on port 1
        wait for PERIOD * 3;
        mux_send_beat(1, x"B0", '1');
        wait for PERIOD * 5;

        if mux_beats_rx /= 3 then
            report "MUX: expected 3 output beats, got " & integer'image(mux_beats_rx)
                   severity error;
            errors <= errors + 1;
        end if;

        -- =====================================================================
        -- DEMUX test: route to port 1 then port 0 using tdest
        -- =====================================================================
        dmx_m_ready <= (others => '1');

        dmx_send_beat("1", x"CC", '1');
        wait for PERIOD * 3;
        if dmx1_data_rx /= x"CC" then
            report "DEMUX port 1 data mismatch: got " & to_hstring(dmx1_data_rx)
                   severity error;
            errors <= errors + 1;
        end if;

        dmx_send_beat("0", x"DD", '1');
        wait for PERIOD * 3;
        if dmx0_data_rx /= x"DD" then
            report "DEMUX port 0 data mismatch: got " & to_hstring(dmx0_data_rx)
                   severity error;
            errors <= errors + 1;
        end if;

        wait for PERIOD * 2;

        if errors = 0 then
            report "tb_axis_mux_demux: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_mux_demux: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
