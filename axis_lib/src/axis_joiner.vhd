-- =============================================================================
-- axis_joiner.vhd
-- AXI-Stream N-stream Joiner.
-- Collects one beat from each of N input streams and combines them into a
-- single wider output beat.  All N inputs must be valid simultaneously before
-- any is accepted.  The combined output beat is valid when all inputs are ready.
-- tlast is asserted on the output when ALL inputs assert tlast.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.axis_pkg.all;

entity axis_joiner is
    generic (
        N_PORTS    : positive := 2;   -- Number of input streams to join
        DATA_WIDTH : positive := 8;   -- Width of EACH input stream
        USER_WIDTH : natural  := 1;
        ID_WIDTH   : natural  := 1;
        DEST_WIDTH : natural  := 1
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

        -- Master (single wide output)
        -- Output data is: port(N-1) concatenated with ... with port(0)
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(N_PORTS * DATA_WIDTH - 1 downto 0);
        m_axis_tkeep  : out std_logic_vector(N_PORTS * (DATA_WIDTH / 8) - 1 downto 0);
        m_axis_tlast  : out std_logic;
        -- tuser/tid/tdest from port 0 are used for the output
        m_axis_tuser  : out std_logic_vector(USER_WIDTH - 1 downto 0);
        m_axis_tid    : out std_logic_vector(ID_WIDTH   - 1 downto 0);
        m_axis_tdest  : out std_logic_vector(DEST_WIDTH - 1 downto 0)
    );
end entity axis_joiner;

architecture rtl of axis_joiner is

    -- all_valid: all N inputs have valid data
    signal all_valid : std_logic;

begin

    -- All inputs must be valid
    process (s_axis_tvalid) is
        variable v : std_logic;
    begin
        v := '1';
        for i in 0 to N_PORTS - 1 loop
            v := v and s_axis_tvalid(i);
        end loop;
        all_valid <= v;
    end process;

    m_axis_tvalid <= all_valid;

    -- Each slave is ready only when all inputs are valid AND master is ready
    process (all) is
    begin
        for i in 0 to N_PORTS - 1 loop
            s_axis_tready(i) <= all_valid and m_axis_tready;
        end loop;
    end process;

    -- Output data = concatenation of all port data
    m_axis_tdata <= s_axis_tdata;
    m_axis_tkeep <= s_axis_tkeep;

    -- tlast when all ports assert tlast
    process (s_axis_tlast) is
        variable v : std_logic;
    begin
        v := '1';
        for i in 0 to N_PORTS - 1 loop
            v := v and s_axis_tlast(i);
        end loop;
        m_axis_tlast <= v;
    end process;

    -- sideband from port 0
    m_axis_tuser <= s_axis_tuser(USER_WIDTH - 1 downto 0);
    m_axis_tid   <= s_axis_tid  (ID_WIDTH   - 1 downto 0);
    m_axis_tdest <= s_axis_tdest(DEST_WIDTH - 1 downto 0);

end architecture rtl;
