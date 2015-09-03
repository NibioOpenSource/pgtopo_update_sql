-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info);

-- Find topology layer_id info for the structure topo_update.input_meta_info

CREATE OR REPLACE FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
layer_id_res int;
BEGIN

	SELECT layer_id 
	FROM topology.layer l, topology.topology t 
	WHERE t.name = topo_info.topology_name AND
	t.id = l.topology_id AND
	l.schema_name = topo_info.layer_schema_name AND
	l.table_name = topo_info.layer_table_name AND
	l.feature_column = topo_info.layer_feature_column
	INTO layer_id_res;
	
	return layer_id_res;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info)  IS ' Find topology layer_id info for the structure topo_update.input_meta_info';

-- test the function with goven structure
-- DO $$
-- DECLARE 
-- topo_info topo_update.input_meta_info;
-- BEGIN
-- 	topo_info.topology_name := 'topo_rein_sysdata';
-- 	topo_info.layer_schema_name := 'topo_rein';
-- 	topo_info.layer_table_name := 'arstidsbeite_var_grense';
-- 	topo_info.layer_feature_column := 'grense';
-- 	RAISE NOTICE 'topo_update.get_topo_layer_id returns %',  topo_update.get_topo_layer_id(topo_info);
-- END $$;

