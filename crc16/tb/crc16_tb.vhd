-- CRC16 testbench
--
-- Verifies two standard CRC16 variants against the industry-standard
-- test vector "123456789" (ASCII bytes 0x31..0x39):
--
--   CRC16-CCITT  expected: 0x29B1
--   CRC16-IBM    expected: 0xBB3D
--
-- Also verifies the check mode: feeding message + appended CRC bytes back
-- through the calculator produces a zero residue for both variants.
--   CRC-CCITT: append checksum big-endian  {0x29, 0xB1} → residue 0x0000
--   CRC-IBM  : append checksum little-endian {0x3D, 0xBB} → residue 0x0000

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity crc16_tb is
end entity crc16_tb;

architecture tb of crc16_tb is

    constant CLK_PERIOD : time := 10 ns;

    -- Shared control signals (driven identically to both DUTs)
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal clr   : std_logic := '0';
    signal valid : std_logic := '0';

    -- Per-DUT data / output buses
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal crc_ccitt  : std_logic_vector(15 downto 0);
    signal crc_ibm    : std_logic_vector(15 downto 0);
    signal par_ccitt  : std_logic;
    signal par_ibm    : std_logic;

    -- "123456789" in ASCII
    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);
    constant MSG : byte_array_t(0 to 8) := (
        x"31", x"32", x"33", x"34", x"35",
        x"36", x"37", x"38", x"39"
    );

    -- Helper: feed an array of bytes into the DUTs
    procedure send_bytes(
        signal   s_clk   : in  std_logic;
        signal   s_valid : out std_logic;
        signal   s_data  : out std_logic_vector(7 downto 0);
        constant bytes   : in  byte_array_t
    ) is
    begin
        for i in bytes'range loop
            s_data  <= bytes(i);
            s_valid <= '1';
            wait until rising_edge(s_clk);
        end loop;
        s_valid <= '0';
        wait until rising_edge(s_clk);  -- let final word settle
    end procedure;

begin

    -- -----------------------------------------------------------------------
    -- DUT 1: CRC16-CCITT  (poly=0x1021, init=0xFFFF, no reflection)
    -- -----------------------------------------------------------------------
    dut_ccitt : entity work.crc16
        generic map (
            DATA_WIDTH => 8,
            POLY       => x"1021",
            CRC_INIT   => x"FFFF",
            REFIN      => false,
            REFOUT     => false,
            XOROUT     => x"0000"
        )
        port map (
            clk    => clk,
            rst    => rst,
            clr    => clr,
            valid  => valid,
            data   => data_in,
            crc    => crc_ccitt,
            parity => par_ccitt
        );

    -- -----------------------------------------------------------------------
    -- DUT 2: CRC16-IBM  (poly=0x8005, init=0x0000, reflected I/O)
    -- -----------------------------------------------------------------------
    dut_ibm : entity work.crc16
        generic map (
            DATA_WIDTH => 8,
            POLY       => x"8005",
            CRC_INIT   => x"0000",
            REFIN      => true,
            REFOUT     => true,
            XOROUT     => x"0000"
        )
        port map (
            clk    => clk,
            rst    => rst,
            clr    => clr,
            valid  => valid,
            data   => data_in,
            crc    => crc_ibm,
            parity => par_ibm
        );

    -- -----------------------------------------------------------------------
    -- Clock
    -- -----------------------------------------------------------------------
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- -----------------------------------------------------------------------
    -- Stimulus & self-checking
    -- -----------------------------------------------------------------------
    stim_proc : process

        -- CRC-CCITT check bytes for "123456789" appended MSB-first:
        --   checksum = 0x29B1 → bytes: 0x29, 0xB1
        constant CCITT_CRC_BYTES : byte_array_t(0 to 1) := (x"29", x"B1");
        -- CRC-IBM check bytes for "123456789" appended little-endian
        -- (reflected algorithm → LSB first):  0xBB3D → bytes: 0x3D, 0xBB
        constant IBM_CRC_BYTES   : byte_array_t(0 to 1) := (x"3D", x"BB");

        variable ccitt_chk : std_logic_vector(15 downto 0);
        variable ibm_chk   : std_logic_vector(15 downto 0);

    begin
        -- Reset
        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        rst <= '0';
        wait until rising_edge(clk);

        -- ---- Generator test ------------------------------------------------
        send_bytes(clk, valid, data_in, MSG);
        assert crc_ccitt = x"29B1"
            report "FAIL CRC16-CCITT: expected 0x29B1, got 0x" &
                   to_hstring(crc_ccitt)
            severity failure;
        report "PASS CRC16-CCITT generator: 0x" & to_hstring(crc_ccitt)
            severity note;

        -- Check CRC16-IBM result
        assert crc_ibm = x"BB3D"
            report "FAIL CRC16-IBM: expected 0xBB3D, got 0x" &
                   to_hstring(crc_ibm)
            severity failure;
        report "PASS CRC16-IBM generator: 0x" & to_hstring(crc_ibm)
            severity note;

        -- ---- Check (receiver) test -----------------------------------------
        -- Feed the same message again, then the appended CRC bytes.
        -- A correct implementation must produce the known residue.

        -- CCITT check
        clr <= '1';
        wait until rising_edge(clk);
        clr <= '0';
        send_bytes(clk, valid, data_in, MSG);
        send_bytes(clk, valid, data_in, CCITT_CRC_BYTES);
        ccitt_chk := crc_ccitt;
        assert ccitt_chk = x"0000"
            report "FAIL CRC16-CCITT check residue: expected 0x0000, got 0x" &
                   to_hstring(ccitt_chk)
            severity failure;
        report "PASS CRC16-CCITT check residue: 0x" & to_hstring(ccitt_chk)
            severity note;

        -- IBM check
        clr <= '1';
        wait until rising_edge(clk);
        clr <= '0';
        send_bytes(clk, valid, data_in, MSG);
        send_bytes(clk, valid, data_in, IBM_CRC_BYTES);
        ibm_chk := crc_ibm;
        assert ibm_chk = x"0000"
            report "FAIL CRC16-IBM check residue: expected 0x0000, got 0x" &
                   to_hstring(ibm_chk)
            severity failure;
        report "PASS CRC16-IBM check residue: 0x" & to_hstring(ibm_chk)
            severity note;

        report "All CRC16 tests PASSED." severity note;
        std.env.stop;
    end process;

end architecture tb;
