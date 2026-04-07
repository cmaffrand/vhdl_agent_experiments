-------------------------------------------------------------------------------
-- Package : axis_pkg
-- Description : AXI4-Stream (AXIS) interface type definitions.
--               Provides record types for the master-side signals (t_axis_mst)
--               and the slave-side signal (t_axis_slv) of an AXIS channel.
--
-- Signal ownership per AXIS specification:
--   Master drives : TVALID, TDATA, TSTRB, TKEEP, TLAST, TID, TDEST, TUSER
--   Slave  drives : TREADY
--
-- The records use unconstrained std_logic_vector elements (VHDL-2008).
-- When instantiating ports, constrain the vectors to the required widths,
-- e.g.:
--   signal m_axis : t_axis_mst(tdata(31 downto 0),
--                               tstrb( 3 downto 0),
--                               tkeep( 3 downto 0),
--                               tid  ( 7 downto 0),
--                               tdest( 3 downto 0),
--                               tuser(15 downto 0));
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package axis_pkg is

  -- -------------------------------------------------------------------------
  -- Master-side signals of an AXI4-Stream channel.
  -- The master drives all fields of this record toward the slave.
  -- -------------------------------------------------------------------------
  type t_axis_mst is record
    tvalid : std_logic;                      -- Transfer valid
    tdata  : std_logic_vector;               -- Transfer data
    tstrb  : std_logic_vector;               -- Byte strobe (indicates valid data bytes)
    tkeep  : std_logic_vector;               -- Byte enable (marks bytes for transport)
    tlast  : std_logic;                      -- End-of-packet indicator
    tid    : std_logic_vector;               -- Stream identifier
    tdest  : std_logic_vector;               -- Routing destination
    tuser  : std_logic_vector;               -- User-defined sideband data
  end record t_axis_mst;

  -- -------------------------------------------------------------------------
  -- Slave-side signals of an AXI4-Stream channel.
  -- The slave drives this record back toward the master.
  -- -------------------------------------------------------------------------
  type t_axis_slv is record
    tready : std_logic;                      -- Slave ready to accept data
  end record t_axis_slv;

  -- -------------------------------------------------------------------------
  -- Helper constants for a default (de-asserted) state of each record.
  -- Useful for resetting or tying off unused interfaces.
  -- Note: vector widths must be overridden at the point of use.
  -- -------------------------------------------------------------------------
  constant C_AXIS_MST_DEFAULT : t_axis_mst(
    tdata(0 downto 0),
    tstrb(0 downto 0),
    tkeep(0 downto 0),
    tid  (0 downto 0),
    tdest(0 downto 0),
    tuser(0 downto 0)
  ) := (
    tvalid => '0',
    tdata  => (others => '0'),
    tstrb  => (others => '0'),
    tkeep  => (others => '0'),
    tlast  => '0',
    tid    => (others => '0'),
    tdest  => (others => '0'),
    tuser  => (others => '0')
  );

  constant C_AXIS_SLV_DEFAULT : t_axis_slv := (
    tready => '0'
  );

end package axis_pkg;
