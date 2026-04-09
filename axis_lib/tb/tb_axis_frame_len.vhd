-- =============================================================================
-- tb_axis_frame_len.vhd
-- Testbench for axis_frame_len checker
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axis_frame_len is
end entity tb_axis_frame_len;

architecture sim of tb_axis_frame_len is

    constant DATA_W : positive := 8;
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

    signal m_valid : std_logic;
    signal m_ready : std_logic := '1';
    signal m_data  : std_logic_vector(DATA_W-1 downto 0);
    signal m_keep  : std_logic_vector(0 downto 0);
    signal m_last  : std_logic;
    signal m_user  : std_logic_vector(0 downto 0);
    signal m_id    : std_logic_vector(0 downto 0);
    signal m_dest  : std_logic_vector(0 downto 0);

    signal frame_len : std_logic_vector(15 downto 0);
    signal err_short : std_logic;
    signal err_long  : std_logic;

    -- Latched status captured on tlast cycle
    signal cap_len   : std_logic_vector(15 downto 0) := (others => '0');
    signal cap_short : std_logic := '0';
    signal cap_long  : std_logic := '0';
    signal cap_done  : std_logic := '0';  -- pulses for one delta after capture

    signal errors : natural := 0;

begin

    aclk <= not aclk after PERIOD / 2;

    dut : entity work.axis_frame_len
        generic map (
            DATA_WIDTH => DATA_W, USER_WIDTH => 1, ID_WIDTH => 1, DEST_WIDTH => 1,
            MIN_FRAME_BYTES => 4,   -- minimum 4 bytes
            MAX_FRAME_BYTES => 8,   -- maximum 8 bytes
            LEN_BITS => 16
        )
        port map (
            aclk => aclk, aresetn => aresetn,
            s_axis_tvalid => s_valid, s_axis_tready => s_ready,
            s_axis_tdata  => s_data,  s_axis_tkeep  => s_keep,
            s_axis_tlast  => s_last,  s_axis_tuser  => s_user,
            s_axis_tid    => s_id,    s_axis_tdest  => s_dest,
            m_axis_tvalid => m_valid, m_axis_tready => m_ready,
            m_axis_tdata  => m_data,  m_axis_tkeep  => m_keep,
            m_axis_tlast  => m_last,  m_axis_tuser  => m_user,
            m_axis_tid    => m_id,    m_axis_tdest  => m_dest,
            frame_len_o => frame_len,
            err_short_o => err_short,
            err_long_o  => err_long
        );

    -- Monitor: capture outputs on the beat where tlast is accepted
    monitor : process (aclk) is
    begin
        if rising_edge(aclk) then
            cap_done <= '0';
            if m_valid = '1' and m_ready = '1' and m_last = '1' then
                cap_len   <= frame_len;
                cap_short <= err_short;
                cap_long  <= err_long;
                cap_done  <= '1';
            end if;
        end if;
    end process;

    stim : process is
        procedure send_packet (num_beats : positive) is
        begin
            for i in 1 to num_beats loop
                s_data  <= std_logic_vector(to_unsigned(i, DATA_W));
                if i = num_beats then
                    s_last <= '1';
                else
                    s_last <= '0';
                end if;
                s_valid <= '1';
                wait until rising_edge(aclk) and s_ready = '1';
            end loop;
            s_valid <= '0';
            s_last  <= '0';
        end procedure;
    begin
        -- Reset
        aresetn <= '0';
        wait for PERIOD * 3;
        wait until rising_edge(aclk);
        aresetn <= '1';
        m_ready <= '1';
        wait for PERIOD;

        -- Test 1: Normal frame (6 bytes) – should be OK
        send_packet(6);
        wait until rising_edge(aclk) and cap_done = '1';
        wait for 1 ns;  -- let cap_ signals settle
        if cap_short = '1' or cap_long = '1' then
            report "Unexpected error for 6-byte frame (short=" &
                   std_ulogic'image(cap_short) & " long=" &
                   std_ulogic'image(cap_long) & ")" severity error;
            errors <= errors + 1;
        end if;
        if unsigned(cap_len) /= 6 then
            report "Frame length mismatch: got " & integer'image(to_integer(unsigned(cap_len)))
                   & " expected 6" severity error;
            errors <= errors + 1;
        end if;
        wait for PERIOD * 3;

        -- Test 2: Short frame (2 bytes) – should trigger err_short
        send_packet(2);
        wait until rising_edge(aclk) and cap_done = '1';
        wait for 1 ns;
        if cap_short /= '1' then
            report "Expected err_short for 2-byte frame" severity error;
            errors <= errors + 1;
        end if;
        wait for PERIOD * 3;

        -- Test 3: Long frame (10 bytes) – should trigger err_long
        send_packet(10);
        wait until rising_edge(aclk) and cap_done = '1';
        wait for 1 ns;
        if cap_long /= '1' then
            report "Expected err_long for 10-byte frame" severity error;
            errors <= errors + 1;
        end if;
        wait for PERIOD * 3;

        if errors = 0 then
            report "tb_axis_frame_len: ALL TESTS PASSED" severity note;
        else
            report "tb_axis_frame_len: " & integer'image(errors) & " ERRORS" severity failure;
        end if;
        wait;
    end process;

end architecture sim;
