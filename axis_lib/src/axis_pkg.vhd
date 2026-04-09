-- =============================================================================
-- axis_pkg.vhd
-- Common package for the AXIS library: types, constants and utility functions
-- =============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package axis_pkg is

    -- -------------------------------------------------------------------------
    -- Utility functions
    -- -------------------------------------------------------------------------
    -- Return the number of bits needed to represent 0 .. n-1
    function clog2(n : positive) return natural;

    -- Byte-enable width derived from data width in bits
    function keep_width(data_width : positive) return positive;

end package axis_pkg;

package body axis_pkg is

    function clog2(n : positive) return natural is
        variable v : natural := 0;
        variable x : positive := 1;
    begin
        while x < n loop
            v := v + 1;
            x := x * 2;
        end loop;
        return v;
    end function clog2;

    function keep_width(data_width : positive) return positive is
    begin
        return (data_width + 7) / 8;
    end function keep_width;

end package body axis_pkg;
