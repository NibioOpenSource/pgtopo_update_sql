-- Find topology layer_id info for given input structure

-- DROP FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info);

-- Get the new line string with no loose ends, where not left_face and right_phase is null


CREATE OR REPLACE FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) 
RETURNS geometry AS $$DECLARE
DECLARE 
edge_with_out_loose_ends geometry;
command_string text;
BEGIN

	-- create command string
	command_string := FORMAT('
	 	SELECT ST_union(ed.geom)  
		FROM 
		%1$s re,
		%2$s ed
		WHERE 
		%3$s  = re.topogeo_id AND
		re.layer_id =  topo_update.get_topo_layer_id( %4$L ) AND 
		re.element_type = %5$L AND 
		ed.edge_id = re.element_id AND
		NOT (ed.left_face = 0 AND ed.right_face = 0) AND 
		NOT (ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
		', 
		topo_info.topology_name || '.relation', -- the edge data name
		topo_info.topology_name || '.edge_data', -- the edge data name
		topo.id, -- get feature colmun name
		topo_info, -- Used to find layer_id
		topo_info.element_type -- Ser correct layer_type, 2 for egde
		
	);
		
    -- display the string
    -- RAISE NOTICE '%', command_string;

	-- execute the string
    EXECUTE command_string INTO edge_with_out_loose_ends;
		
    -- Put this together to on single line string
    -- TODO check if this is save Is this safe ???
    
	RETURN ST_LineMerge(edge_with_out_loose_ends);

END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry)  IS 'Get the new line string with no loose ends';

-- test the function with goven structure
--DO $$
--DECLARE 
--topo_info topo_update.input_meta_info;
--BEGIN
--	topo_info.topology_name := 'topo_rein_sysdata';
--	topo_info.layer_schema_name := 'topo_rein';
--	topo_info.layer_table_name := 'arstidsbeite_var_grense';
--	topo_info.layer_feature_column := 'grense';
--	topo_info.element_type := 2;
--	RAISE NOTICE 'topo_update.get_linestring_no_loose_ends returns %',  topo_update.get_linestring_no_loose_ends(topo_info, 
-- 	(SELECT grense FROM topo_rein.arstidsbeite_var_grense limit 1 )::topogeometry);
--END $$;

