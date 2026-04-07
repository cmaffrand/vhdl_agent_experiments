-- =============================================================================
-- axis_mux.vhd
-- AXI-Stream N-to-1 Multiplexer.
-- Selects one of N slave (input) streams to forward to the master (output).
-- Arbitration policy selectable via generic:
--   ARB_TYPE = 0 : Fixed priority  (port 0 highest, N-1 lowest)
--   ARB_TYPE = 1 : Round-robin     (cycles through active inputs)
--
-- Port arrays use a flat std_logic_vector where each port occupies a contiguous
-- DATA_WIDTH-bit slice: port k occupies bits [(k+1)*W-1 : k*W].
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_mux is
    generic (
        N_PORTS    : positive := 2;   -- Number of input ports
        DATA_WIDTH : positive := 8;
        USER_WIDTH : natural  := 1;
        ID_WIDTH   : natural  := 1;
        DEST_WIDTH : natural  := 1;
        ARB_TYPE   : natural  := 1    -- 0=fixed-priority, 1=round-robin
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (N inputs) – flat vectors, port k at [(k+1)*W-1:k*W]
        s_axis_tvalid : in  std_logic_vector(N_PORTS - 1 downto 0);
        s_axis_tready : out std_logic_vector(N_PORTS - 1 downto 0);
        s_axis_tdata  : in  std_logic_vector(N_PORTS * DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector(N_PORTS * (DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic_vector(N_PORTS - 1 downto 0);
        s_axis_tuser  : in  std_logic_vector(N_PORTS * USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(N_PORTS * ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(N_PORTS * DEST_WIDTH - 1 downto 0);

        -- Master (single output)
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic;
        m_axis_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0)
    );
end entity axis_mux;

architecture rtl of axis_mux is

    constant KEEP_W  : natural := DATA_WIDTH / 8;
    constant SEL_W   : natural := clog2(N_PORTS);

    signal selected  : unsigned(SEL_W - 1 downto 0) := (others => '0');
    signal rr_ptr    : unsigned(SEL_W - 1 downto 0) := (others => '0');

    signal in_packet : std_logic := '0';   -- '1' while forwarding a packet
    signal grant     : unsigned(SEL_W - 1 downto 0) := (others => '0');

    -- Helper: extract field for a specific port
    function get_data(v : std_logic_vector; idx : natural; w : natural)
        return std_logic_vector is
    begin
        return v((idx + 1) * w - 1 downto idx * w);
    end function;

begin

    -- Arbitration: runs at the start of each new packet (when in_packet = '0')
    process (aclk) is
        variable found : boolean;
        variable next_g : unsigned(SEL_W - 1 downto 0);
        variable idx    : natural range 0 to N_PORTS - 1;
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                grant     <= (others => '0');
                rr_ptr    <= (others => '0');
                in_packet <= '0';
            else
                -- Track whether we are mid-packet
                if in_packet = '1' then
                    if s_axis_tvalid(to_integer(grant)) = '1'
                       and m_axis_tready = '1'
                       and s_axis_tlast(to_integer(grant)) = '1' then
                        in_packet <= '0';
                    end if;
                else
                    -- Arbitrate for next packet
                    found  := false;
                    next_g := rr_ptr;

                    if ARB_TYPE = 0 then
                        -- Fixed priority: lowest index wins
                        for i in 0 to N_PORTS - 1 loop
                            if not found and s_axis_tvalid(i) = '1' then
                                next_g := to_unsigned(i, SEL_W);
                                found  := true;
                            end if;
                        end loop;
                    else
                        -- Round-robin: start search from rr_ptr
                        for i in 0 to N_PORTS - 1 loop
                            idx := (to_integer(rr_ptr) + i) mod N_PORTS;
                            if not found and s_axis_tvalid(idx) = '1' then
                                next_g := to_unsigned(idx, SEL_W);
                                found  := true;
                            end if;
                        end loop;
                    end if;

                    if found then
                        grant     <= next_g;
                        in_packet <= '1';
                        -- Advance round-robin pointer past current winner
                        rr_ptr <= to_unsigned((to_integer(next_g) + 1) mod N_PORTS, SEL_W);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- Output mux
    process (all) is
        variable g : natural range 0 to N_PORTS - 1;
    begin
        g := to_integer(grant);

        s_axis_tready <= (others => '0');

        if in_packet = '1' then
            m_axis_tvalid <= s_axis_tvalid(g);
            m_axis_tdata  <= get_data(s_axis_tdata, g, DATA_WIDTH);
            m_axis_tkeep  <= get_data(s_axis_tkeep, g, KEEP_W);
            m_axis_tlast  <= s_axis_tlast(g);
            m_axis_tuser  <= get_data(s_axis_tuser, g, USER_WIDTH);
            m_axis_tid    <= get_data(s_axis_tid,   g, ID_WIDTH);
            m_axis_tdest  <= get_data(s_axis_tdest, g, DEST_WIDTH);
            s_axis_tready(g) <= m_axis_tready;
        else
            m_axis_tvalid <= '0';
            m_axis_tdata  <= (others => '0');
            m_axis_tkeep  <= (others => '0');
            m_axis_tlast  <= '0';
            m_axis_tuser  <= (others => '0');
            m_axis_tid    <= (others => '0');
            m_axis_tdest  <= (others => '0');
        end if;
    end process;

end architecture rtl;
