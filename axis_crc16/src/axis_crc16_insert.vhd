-- =============================================================================
-- axis_crc16_insert.vhd
-- AXI-Stream CRC16 Inserter.
--
-- Computes a CRC16 checksum over the incoming payload bytes and appends the
-- 2-byte result to the outgoing packet (big-endian: MSB byte first, then LSB
-- byte).  The output packet is exactly 2 bytes longer than the input packet.
--
-- The DATA_WIDTH generic should be set to 8 (one byte per beat) so that the
-- two CRC bytes map cleanly to two output beats.
--
-- CRC16-CCITT defaults (POLY=0x1021, INIT=0xFFFF, REFIN=false, REFOUT=false,
-- XOROUT=0x0000) produce the standard "123456789" → 0x29B1 checksum, which
-- is then appended as [0x29, 0xB1].
--
-- FSM states:
--   PASS : normal data pass-through; CRC accumulates on every accepted beat.
--          When s_axis_tlast is accepted, tlast is suppressed on the output
--          and the FSM moves to CRC1.
--   CRC1 : outputs the high CRC byte (crc[15:8]) without tlast.
--   CRC2 : outputs the low  CRC byte (crc[ 7:0]) with    tlast.
--          On the accepted beat the CRC calculator is cleared, ready for
--          the next frame.
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.crc16_pkg.all;

entity axis_crc16_insert is
    generic (
        DATA_WIDTH : positive                       := 8;
        POLY       : std_logic_vector(15 downto 0) := x"1021";
        CRC_INIT   : std_logic_vector(15 downto 0) := x"FFFF";
        REFIN      : boolean                        := false;
        REFOUT     : boolean                        := false;
        XOROUT     : std_logic_vector(15 downto 0) := x"0000"
    );
    port (
        aclk    : in  std_logic;
        aresetn : in  std_logic;

        -- Slave (input) interface
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;
        s_axis_tdata  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        s_axis_tlast  : in  std_logic;

        -- Master (output) interface – packet extended with 2 CRC bytes
        m_axis_tvalid : out std_logic;
        m_axis_tready : in  std_logic;
        m_axis_tdata  : out std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tlast  : out std_logic
    );
end entity axis_crc16_insert;

architecture rtl of axis_crc16_insert is

    -- FSM
    type state_t is (PASS, CRC1, CRC2);
    signal state : state_t := PASS;

    -- Inverted reset for the crc16 sub-module (active-high rst)
    signal rst_int : std_logic;

    -- CRC sub-module control and output
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

    -- Feed the CRC calculator only while passing payload data through.
    -- A beat is consumed when both valid and ready are asserted.
    crc_valid <= s_axis_tvalid and m_axis_tready when state = PASS else '0';

    -- Clear the CRC on the cycle the second CRC byte is accepted.
    -- The clear takes effect on the following rising edge so crc_out remains
    -- stable and correct throughout the CRC2 beat.
    crc_clr <= m_axis_tready when state = CRC2 else '0';

    -- -------------------------------------------------------------------------
    -- FSM register
    -- -------------------------------------------------------------------------
    process (aclk) is
    begin
        if rising_edge(aclk) then
            if aresetn = '0' then
                state <= PASS;
            else
                case state is
                    when PASS =>
                        -- When the last payload beat is accepted, move on to
                        -- inject the CRC bytes.
                        if s_axis_tvalid = '1' and m_axis_tready = '1' and
                           s_axis_tlast  = '1' then
                            state <= CRC1;
                        end if;

                    when CRC1 =>
                        if m_axis_tready = '1' then
                            state <= CRC2;
                        end if;

                    when CRC2 =>
                        if m_axis_tready = '1' then
                            state <= PASS;
                        end if;
                end case;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------
    -- Output multiplexer (combinatorial)
    -- -------------------------------------------------------------------------
    process (all) is
    begin
        case state is
            when PASS =>
                -- Pass payload through; suppress tlast (CRC bytes come after).
                s_axis_tready <= m_axis_tready;
                m_axis_tvalid <= s_axis_tvalid;
                m_axis_tdata  <= s_axis_tdata;
                m_axis_tlast  <= '0';

            when CRC1 =>
                -- High CRC byte; block upstream input.
                s_axis_tready <= '0';
                m_axis_tvalid <= '1';
                m_axis_tdata  <= crc_out(15 downto 8);
                m_axis_tlast  <= '0';

            when CRC2 =>
                -- Low CRC byte with tlast; block upstream input.
                s_axis_tready <= '0';
                m_axis_tvalid <= '1';
                m_axis_tdata  <= crc_out(7 downto 0);
                m_axis_tlast  <= '1';
        end case;
    end process;

end architecture rtl;
