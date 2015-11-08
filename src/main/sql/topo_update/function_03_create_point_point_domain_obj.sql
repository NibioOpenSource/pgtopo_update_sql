-- This a function that will be called from the client when user is drawing a point 
-- This line will be applied the data in the point layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- DROP FUNCTION FUNCTION topo_update.create_point_point_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_point_point_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;


-- this border layer id will picked up by input parameters
point_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

-- TODO use as parameter put for testing we just have here for now
point_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

BEGIN
	
	
	-- TODO to be moved is justed for testing now
	point_topo_info.topology_name := 'topo_rein_sysdata';
	point_topo_info.layer_schema_name := 'topo_rein';
	point_topo_info.layer_table_name := 'reindrift_anlegg_punkt';
	point_topo_info.layer_feature_column := 'punkt';
	point_topo_info.snap_tolerance := 0.0000000001;
	point_topo_info.element_type = 1;
	
		-- find point layer id
	point_layer_id := topo_update.get_topo_layer_id(point_topo_info);

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
	CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM  topo_rein.reindrift_anlegg_punkt limit 0);
	WITH inserted AS (
		INSERT INTO topo_rein.reindrift_anlegg_punkt(punkt, felles_egenskaper, reindriftsanleggstype,reinbeitebruker_id)
		SELECT  
			topology.toTopoGeom(t2.geom, point_topo_info.topology_name, point_layer_id, point_topo_info.snap_tolerance) AS punkt,
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
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.punkt::geometry && tg.punkt::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

--select topo_update.create_point_point_domain_obj('{"type": "Feature","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"geometry":{"type":"Point","coordinates":[17.4122416312598,68.6013397740665]},"properties":{"reinbeitebruker_id":"XG","reindriftsanleggstype":18}}');

