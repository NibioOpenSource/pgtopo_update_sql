-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


CREATE OR REPLACE FUNCTION topo_update.create_line_edge_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- used for logging
add_debug_tables int = 0;

-- the number times the inlut line intersects
num_edge_intersects int;

line_intersection_result geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

BEGIN
	
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'reindrift_anlegg_linje';
	border_topo_info.layer_feature_column := 'linje';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;


	-- get the json values
	
	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 

		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);


	END IF;

	-- insert the data in the org table and keep a copy of the data
	DROP TABLE IF EXISTS new_rows_added_in_org_table;
	CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM  topo_rein.reindrift_anlegg_linje limit 0);
	WITH inserted AS (
		INSERT INTO topo_rein.reindrift_anlegg_linje(linje, felles_egenskaper, reindriftsanleggstype,reinbeitebruker_id)
		SELECT  
			topology.toTopoGeom(t2.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance) AS linje,
			felles_egenskaper_linje AS felles_egenskaper,
			(t2.properties->>'reindriftsanleggstype')::int AS reindriftsanleggstype,
			(t2.properties->>'reinbeitebruker_id')::text AS reinbeitebruker_id
		FROM ttt_new_attributes_values t2
		RETURNING *
	)
	INSERT INTO new_rows_added_in_org_table
	SELECT * FROM inserted;

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT tg.id AS id FROM  new_rows_added_in_org_table tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.linje::geometry && tg.linje::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;


-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[23.6848135256,70.2941567505],[23.6861561246,70.2937237249],[23.6888489507,70.2928551851],[23.6896495555,70.2925466063],[23.6917889589,70.292156264],[23.6945956663,70.2918661088],[23.6965659512,70.2915742147],[23.6997477211,70.2913270875],[23.7033391524,70.2915039485],[23.7044653963,70.2916332891],[23.7071834727,70.2915684568],[23.7076455811,70.2914565778],[23.7081927635,70.2912602126],[23.7079468414,70.2907122103]]},"properties":{"reinbeitebruker_id":"YD","reindriftsanleggstype":1}}');

-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[582408.943892817,7635222.4433961185],[621500.8918835252,7615523.766478926],[622417.1094145575,7630641.355740958]],"crs":{"type":"name","properties":{"name":"EPSG:32633"}}},"properties":{"Fellesegenskaper.Opphav":"Y","anleggstype":"12","reinbeitebruker_id ":"ZS","Fellesegenskaper.Kvalitet.Maalemetode":82}}');
