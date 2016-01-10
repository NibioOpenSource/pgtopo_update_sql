-- DROP FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass) 

-- Return 1 if this line has no loose ends or the lines are not part of any surface
-- test the function with goven structure


CREATE OR REPLACE FUNCTION topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) 
RETURNS int AS $$DECLARE
DECLARE 
has_loose_ends int;
command_string text;
BEGIN

	-- create command string
	command_string := FORMAT('
	 	SELECT (EXISTS (SELECT 1  
		FROM 
		%1$s re,
		%2$s ed
		WHERE 
		%3$s  = re.topogeo_id AND
		re.layer_id =  topo_update.get_topo_layer_id( %4$L ) AND 
		re.element_type = %5$L AND 
		ed.edge_id = re.element_id AND
		(
		(ed.left_face = 0 AND ed.right_face = 0) OR
		(ed.left_face > 0 AND ed.right_face > 0 AND ed.left_face = ed.right_face)
		)
		))::int', 
		topo_info.topology_name || '.relation', -- the edge data name
		topo_info.topology_name || '.edge_data', -- the edge data name
		topo.id, -- get feature colmun name
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

COMMENT ON FUNCTION  topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry)  IS 'Return 1 if thIs line has loose ends';


