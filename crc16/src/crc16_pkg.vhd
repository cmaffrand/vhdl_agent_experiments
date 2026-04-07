-- CRC16 helper package
-- Provides bit-reflection and the core parallel CRC16 step function.
-- The step function processes DATA_WIDTH bits per call (MSB first after
-- optional per-word input reflection) and is combinatorial: it can be
-- called inside both processes and pure functions.

library ieee;
use ieee.std_logic_1164.all;

package crc16_pkg is

    -- Reverse the bit order of any std_logic_vector.
    function reflect_slv(v : std_logic_vector) return std_logic_vector;

    -- Advance a CRC16 register by one DATA_WIDTH-bit word.
    --   crc   : current CRC state
    --   data  : input word (any width)
    --   poly  : generator polynomial (normal/non-reflected form)
    --   refin : when true, reflect each input word before processing
    function crc16_step(
        crc   : std_logic_vector(15 downto 0);
        data  : std_logic_vector;
        poly  : std_logic_vector(15 downto 0);
        refin : boolean
    ) return std_logic_vector;

end package crc16_pkg;

package body crc16_pkg is

    function reflect_slv(v : std_logic_vector) return std_logic_vector is
        variable src    : std_logic_vector(v'length - 1 downto 0);
        variable result : std_logic_vector(v'length - 1 downto 0);
    begin
        src := v;
        for i in 0 to src'length - 1 loop
            result(i) := src(src'length - 1 - i);
        end loop;
        return result;
    end function;

    function crc16_step(
        crc   : std_logic_vector(15 downto 0);
        data  : std_logic_vector;
        poly  : std_logic_vector(15 downto 0);
        refin : boolean
    ) return std_logic_vector is
        variable crc_v  : std_logic_vector(15 downto 0);
        variable data_v : std_logic_vector(data'length - 1 downto 0);
        variable fb     : std_logic;
    begin
        crc_v  := crc;
        data_v := data;
        if refin then
            data_v := reflect_slv(data_v);
        end if;
        -- Process bit by bit, MSB first (after optional reflection).
        for i in data_v'length - 1 downto 0 loop
            fb    := crc_v(15) xor data_v(i);
            crc_v := crc_v(14 downto 0) & '0';
            if fb = '1' then
                crc_v := crc_v xor poly;
            end if;
        end loop;
        return crc_v;
    end function;

end package body crc16_pkg;
