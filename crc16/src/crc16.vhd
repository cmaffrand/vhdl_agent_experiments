-- CRC16 generator / checker
--
-- Generic parameters
--   DATA_WIDTH : number of input bits processed per clock cycle (default 8)
--   POLY       : generator polynomial in normal (non-reflected) form
--   CRC_INIT   : initial CRC register value
--   REFIN      : reflect each input word before processing (LSB-first input)
--   REFOUT     : reflect the CRC register before applying XOROUT
--   XOROUT     : final XOR mask applied to the output
--
-- Preset combinations for common CRC16 variants:
--   CRC16-CCITT  : POLY=0x1021  CRC_INIT=0xFFFF REFIN=false REFOUT=false XOROUT=0x0000
--   CRC16-IBM    : POLY=0x8005  CRC_INIT=0x0000 REFIN=true  REFOUT=true  XOROUT=0x0000
--   CRC16-MAXIM  : POLY=0x8005  CRC_INIT=0x0000 REFIN=true  REFOUT=true  XOROUT=0xFFFF
--   CRC16-DNP    : POLY=0x3D65  CRC_INIT=0x0000 REFIN=true  REFOUT=true  XOROUT=0xFFFF
--   CRC16-USB    : POLY=0x8005  CRC_INIT=0xFFFF REFIN=true  REFOUT=true  XOROUT=0xFFFF
--
-- Interface
--   clr   : synchronous clear; resets the CRC register to CRC_INIT on the
--            next rising edge.  Use at the start of each new frame/message.
--   valid : when high the data word is consumed on the rising clock edge.
--   crc   : current CRC output (combinatorial from the CRC register).
--            After all message bytes have been clocked in with valid='1',
--            this port holds the checksum to append (generator mode).
--            When used as a checker, clock in the full message including the
--            appended CRC bytes; a zero result (or the variant-specific
--            residue) indicates no errors.
--   parity: running XOR parity bit accumulated over all processed input bits.

library ieee;
use ieee.std_logic_1164.all;
use work.crc16_pkg.all;

entity crc16 is
    generic (
        DATA_WIDTH : positive                       := 8;
        POLY       : std_logic_vector(15 downto 0) := x"1021";
        CRC_INIT   : std_logic_vector(15 downto 0) := x"FFFF";
        REFIN      : boolean                        := false;
        REFOUT     : boolean                        := false;
        XOROUT     : std_logic_vector(15 downto 0) := x"0000"
    );
    port (
        clk    : in  std_logic;
        rst    : in  std_logic;
        clr    : in  std_logic;
        valid  : in  std_logic;
        data   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
        crc    : out std_logic_vector(15 downto 0);
        parity : out std_logic
    );
end entity crc16;

architecture rtl of crc16 is

    signal crc_reg    : std_logic_vector(15 downto 0) := CRC_INIT;
    signal parity_reg : std_logic                     := '0';

begin

    -- CRC and parity register update (asynchronous reset)
    process(clk, rst)
        variable xor_v : std_logic;
    begin
        if rst = '1' then
            crc_reg    <= CRC_INIT;
            parity_reg <= '0';
        elsif rising_edge(clk) then
            if clr = '1' then
                crc_reg    <= CRC_INIT;
                parity_reg <= '0';
            elsif valid = '1' then
                crc_reg <= crc16_step(crc_reg, data, POLY, REFIN);
                -- XOR-reduce the input word for running parity
                xor_v := '0';
                for i in data'range loop
                    xor_v := xor_v xor data(i);
                end loop;
                parity_reg <= parity_reg xor xor_v;
            end if;
        end if;
    end process;

    -- Output: apply optional output reflection and final XOR mask
    process(crc_reg)
        variable crc_v : std_logic_vector(15 downto 0);
    begin
        if REFOUT then
            crc_v := reflect_slv(crc_reg);
        else
            crc_v := crc_reg;
        end if;
        crc <= crc_v xor XOROUT;
    end process;

    parity <= parity_reg;

end architecture rtl;
