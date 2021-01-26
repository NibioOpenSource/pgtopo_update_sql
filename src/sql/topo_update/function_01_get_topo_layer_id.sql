-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info);

-- Find topology layer_id info for the structure topo_update.input_meta_info

CREATE OR REPLACE FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) 
RETURNS int AS $$DECLARE
DECLARE 
layer_id_res int;

-- holds dynamic sql to be able to use the same code for different
command_string text;

BEGIN

	command_string := FORMAT('SELECT layer_id 
	FROM topology.layer l, topology.topology t 
	WHERE t.name = %L AND
	t.id = l.topology_id AND
	l.schema_name = %L AND
	l.table_name = %L AND
	l.feature_column = %L',
    topo_info.topology_name,
    topo_info.layer_schema_name,
    topo_info.layer_table_name,
    topo_info.layer_feature_column
    );

	EXECUTE command_string INTO layer_id_res;
	
	return layer_id_res;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info)  IS ' Find topology layer_id info for the structure topo_update.input_meta_info';
