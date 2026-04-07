-- =============================================================================
-- axis_broadcaster.vhd
-- AXI-Stream 1-to-N Broadcaster.
-- Replicates a single input stream to all N output ports simultaneously.
-- The input is only consumed when ALL outputs have accepted the current beat
-- (backpressure from any output stalls the others).
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_broadcaster is
    generic (
        N_PORTS    : positive := 2;   -- Number of output ports
        DATA_WIDTH : positive := 8;
        USER_WIDTH : natural  := 1;
        ID_WIDTH   : natural  := 1;
        DEST_WIDTH : natural  := 1
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (single input)
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tkeep  : in  std_logic_vector((DATA_WIDTH / 8) - 1 downto 0);
        s_axis_tlast  : in  std_logic;
        s_axis_tuser  : in  std_logic_vector(USER_WIDTH - 1 downto 0);
        s_axis_tid    : in  std_logic_vector(ID_WIDTH   - 1 downto 0);
        s_axis_tdest  : in  std_logic_vector(DEST_WIDTH - 1 downto 0);

        -- Master (N outputs) – flat vectors, port k at [(k+1)*W-1:k*W]
        m_axis_tvalid : out std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tready : in  std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tdata  : out std_logic_vector(N_PORTS * DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector(N_PORTS * (DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic_vector(N_PORTS - 1 downto 0);
        m_axis_tuser  : out std_logic_vector(N_PORTS * USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(N_PORTS * ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(N_PORTS * DEST_WIDTH - 1 downto 0)
    );
end entity axis_broadcaster;

architecture rtl of axis_broadcaster is

    constant KEEP_W : natural := DATA_WIDTH / 8;

    -- Track which output ports have already consumed the current beat
    signal acked : std_logic_vector(N_PORTS - 1 downto 0) := (others => '0');

    -- A port needs data when it has NOT yet acked the current beat
    signal needs_data : std_logic_vector(N_PORTS - 1 downto 0);

    -- All currently-needing ports are ready
    signal all_ready : std_logic;

begin

    needs_data <= not acked;

    -- Consume input when all outputs are satisfied (either acked or ready now)
    process (all) is
        variable ok : std_logic;
    begin
        ok := '1';
        for i in 0 to N_PORTS - 1 loop
            -- Port i is OK if it has already acked OR is ready this cycle
            if acked(i) = '0' and m_axis_tready(i) = '0' then
                ok := '0';
            end if;
        end loop;
        all_ready <= ok;
    end process;

    s_axis_tready <= all_ready and s_axis_tvalid;

    -- Track per-port acknowledgement
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                acked <= (others => '0');
            else
                if s_axis_tvalid = '1' and all_ready = '1' then
                    -- Beat consumed by all: reset acked
                    acked <= (others => '0');
                else
                    -- Mark ports that accept this cycle (even if not all ready yet)
                    for i in 0 to N_PORTS - 1 loop
                        if s_axis_tvalid = '1'
                           and m_axis_tready(i) = '1'
                           and acked(i) = '0' then
                            acked(i) <= '1';
                        end if;
                    end loop;
                end if;
            end if;
        end if;
    end process;

    -- Output: drive all ports with same data; valid when input valid and not yet acked
    gen_ports : for i in 0 to N_PORTS - 1 generate
        m_axis_tvalid(i) <= s_axis_tvalid and not acked(i);
        m_axis_tdata ((i + 1) * DATA_WIDTH - 1 downto i * DATA_WIDTH) <= s_axis_tdata;
        m_axis_tkeep ((i + 1) * KEEP_W     - 1 downto i * KEEP_W)    <= s_axis_tkeep;
        m_axis_tlast (i) <= s_axis_tlast;
        m_axis_tuser ((i + 1) * USER_WIDTH - 1 downto i * USER_WIDTH) <= s_axis_tuser;
        m_axis_tid   ((i + 1) * ID_WIDTH   - 1 downto i * ID_WIDTH)   <= s_axis_tid;
        m_axis_tdest ((i + 1) * DEST_WIDTH - 1 downto i * DEST_WIDTH) <= s_axis_tdest;
    end generate gen_ports;

end architecture rtl;
