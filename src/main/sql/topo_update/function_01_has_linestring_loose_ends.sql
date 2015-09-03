-- DROP FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass) 

-- Return 1 if this line has no loose ends or the lines are not part of any surface
-- TODO use topo object as input and not a object, since will bee one single topo object,
-- but we may need line attributes then it's easier table as a parameter so we find how to this later. 

CREATE OR REPLACE FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass) 
RETURNS int AS $$DECLARE
DECLARE 
has_loose_ends int;
command_string text;
BEGIN

	-- create command string
	command_string := FORMAT('
	 	SELECT (EXISTS (SELECT 1  
		FROM 
		%1$s ud, 
		%2$s re,
		%3$s ed
		WHERE 
		%4$s  = re.topogeo_id AND
		re.layer_id =  topo_update.get_topo_layer_id( %5$L ) AND 
		re.element_type = %6$L AND 
		ed.edge_id = re.element_id AND
		(
		(ed.left_face = 0 AND ed.right_face = 0) OR
		(ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
		)
		))::int', 
		_tbl,  -- Input table name
		topo_info.topology_name || '.relation', -- the edge data name
		topo_info.topology_name || '.edge_data', -- the edge data name
		'(ud.' || topo_info.layer_feature_column || ').id', -- get feature colmun name
		topo_info, -- Used to find layer_id
		topo_info.element_type -- Ser correct layer_type, 2 for egde
	);
		
    -- display the string
    -- RAISE NOTICE '%', command_string;

    -- execute the string
    EXECUTE command_string INTO has_loose_ends;
		
	RETURN has_loose_ends;

END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION  topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass)  IS 'Return 1 if thIs line has loose ends';

-- test the function with goven structure
-- DO $$
-- DECLARE 
-- topo_info topo_update.input_meta_info;
-- BEGIN
-- 	topo_info.topology_name := 'topo_rein_sysdata';
-- 	topo_info.layer_schema_name := 'topo_rein';
-- 	topo_info.layer_table_name := 'arstidsbeite_var_grense';
-- 	topo_info.layer_feature_column := 'grense';
-- 	topo_info.element_type := 2;
-- 	RAISE NOTICE 'topo_update.has_linestring_loose_ends returns %',  topo_update.has_linestring_loose_ends(topo_info, 'topo_rein.arstidsbeite_var_grense');
-- END $$;

