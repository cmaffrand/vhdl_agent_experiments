-- =============================================================================
-- axis_crc16_check.vhd
-- AXI-Stream CRC16 Checker.
--
-- Receives an AXI-Stream packet whose last two bytes are the CRC16 checksum
-- appended by the transmitter (big-endian: MSB byte first, then LSB byte,
-- matching the output of axis_crc16_insert).
--
-- All bytes – including the two CRC bytes – are fed through an internal CRC16
-- calculator.  When the CRC bytes are correct the accumulated residue equals
-- CRC_RESIDUE (0x0000 for the CRC16-CCITT variant with XOROUT=0x0000).
--
-- The full incoming packet (payload + CRC bytes) is passed through to the
-- master interface unchanged.
--
-- Timing of status outputs
-- ------------------------
-- crc_ok_o / crc_err_o are combinatorial and are valid exactly ONE clock
-- cycle after the tlast beat is accepted.  During that cycle the module
-- asserts clr_pending='1' internally, which briefly stalls the upstream
-- source (s_axis_tready='0') for one cycle so the CRC calculator can be
-- reset before the next frame arrives.
--
-- To read the check result in a test-bench or downstream logic, sample
-- crc_ok_o / crc_err_o on the rising edge AFTER the cycle in which the
-- last beat was accepted.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.crc16_pkg.all;

entity axis_crc16_check is
    generic (
        DATA_WIDTH  : positive                       := 8;
        POLY        : std_logic_vector(15 downto 0) := x"1021";
        CRC_INIT    : std_logic_vector(15 downto 0) := x"FFFF";
        REFIN       : boolean                        := false;
        REFOUT      : boolean                        := false;
        XOROUT      : std_logic_vector(15 downto 0) := x"0000";
        -- Expected CRC residue after processing message + appended CRC bytes.
        -- 0x0000 is correct for CRC16-CCITT (and most variants with XOROUT=0).
        CRC_RESIDUE : std_logic_vector(15 downto 0) := x"0000"
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface – packet includes CRC at the end
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (output) interface – pass-through, data unchanged
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tlast  : out std_logic;

        -- CRC status outputs
        -- Valid one cycle after the tlast beat is accepted (see note above).
        crc_ok_o  : out std_logic;
        crc_err_o : out std_logic
    );
end entity axis_crc16_check;

architecture rtl of axis_crc16_check is

    -- Inverted reset for the crc16 sub-module (active-high rst)
    signal rst_int : std_logic;

    -- One-cycle stall between frames while the CRC calculator is reset.
    signal clr_pending : std_logic := '0';

    -- A beat is accepted when valid, ready, and no stall is pending.
    signal accepted : std_logic;

    -- CRC sub-module signals
    signal crc_valid : std_logic;
    signal crc_clr   : std_logic;
    signal crc_out   : std_logic_vector(15 downto 0);

begin

    rst_int <= not aresetn;

    -- -------------------------------------------------------------------------
    -- CRC16 calculator
    -- -------------------------------------------------------------------------
    u_crc16 : entity work.crc16
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            POLY       => POLY,
            CRC_INIT   => CRC_INIT,
            REFIN      => REFIN,
            REFOUT     => REFOUT,
            XOROUT     => XOROUT
        )
        port map (
            clk    => aclk,
            rst    => rst_int,
            clr    => crc_clr,
            valid  => crc_valid,
            data   => s_axis_tdata,
            crc    => crc_out,
            parity => open
        );

    -- A data beat is accepted only when there is no pending clear (stall).
    accepted  <= s_axis_tvalid and m_axis_tready and not clr_pending;
    crc_valid <= accepted;
    crc_clr   <= clr_pending;

    -- -------------------------------------------------------------------------
    -- Clear-pending register
    -- Set for one cycle after tlast is accepted; cleared automatically.
    -- -------------------------------------------------------------------------
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                clr_pending <= '0';
            elsif clr_pending = '1' then
                clr_pending <= '0';
            elsif accepted = '1' and s_axis_tlast = '1' then
                clr_pending <= '1';
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Pass-through data path
    -- Block for one cycle (clr_pending='1') between frames.
    -- -------------------------------------------------------------------------
    s_axis_tready <= m_axis_tready and not clr_pending;
    m_axis_tvalid <= s_axis_tvalid and not clr_pending;
    m_axis_tdata  <= s_axis_tdata;
    m_axis_tlast  <= s_axis_tlast;

    -- -------------------------------------------------------------------------
    -- CRC status (combinatorial)
    --
    -- crc_ok_o / crc_err_o are driven from clr_pending so they are valid
    -- exactly on the one cycle after tlast acceptance.  At that point:
    --   - clr_pending = '1'  (set at the previous rising edge)
    --   - crc_out           = residue after ALL bytes (including CRC bytes)
    --     because the last byte was clocked into the CRC calculator at the
    --     previous rising edge.
    -- -------------------------------------------------------------------------
    crc_ok_o  <= '1' when (clr_pending = '1' and crc_out = CRC_RESIDUE) else '0';
    crc_err_o <= '1' when (clr_pending = '1' and crc_out /= CRC_RESIDUE) else '0';

end architecture rtl;
