-- This is a simple helper function that createa a common dataholder object based on input objects
-- TODO splitt in different objects dependig we don't send unused parameters around
-- snap_tolerance float8 is optinal if not given default is 0

CREATE OR REPLACE FUNCTION topo_update.make_input_meta_info(layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8 = 0)
RETURNS topo_update.input_meta_info AS $$
DECLARE


topo_info topo_update.input_meta_info ;

BEGIN
	
	
	-- Read parameters
	topo_info.layer_schema_name := layer_schema;
	topo_info.layer_table_name := layer_table;
	topo_info.layer_feature_column := layer_column;
	topo_info.snap_tolerance := snap_tolerance;

-- Find out topology name and element_type from layer identifier
  BEGIN
    SELECT t.name, l.feature_type
    FROM topology.topology t, topology.layer l
    WHERE l.level = 0 -- need be primitive
      AND l.schema_name = topo_info.layer_schema_name
      AND l.table_name = topo_info.layer_table_name
      AND l.feature_column = topo_info.layer_feature_column
      AND t.id = l.topology_id
    INTO STRICT topo_info.topology_name,
                topo_info.element_type;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE EXCEPTION 'Cannot find info for primitive layer %.%.%',
        topo_info.layer_schema_name,
        topo_info.layer_table_name,
        topo_info.layer_feature_column;
  END;

	-- find border layer id
	topo_info.border_layer_id := topo_update.get_topo_layer_id(topo_info);

    return topo_info;
END;
$$ LANGUAGE plpgsql STABLE;
