

-- update attribute values for given topo object
CREATE OR REPLACE FUNCTION topo_update.apply_attr_on_topo_surface(json_feature text) 
RETURNS int AS $$DECLARE

num_rows int;


-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- used to hold values
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;


BEGIN
	
	-- TODO to be moved is justed for testing now
	border_topo_info.topology_name := 'topo_rein_sysdata';
	border_topo_info.layer_schema_name := 'topo_rein';
	border_topo_info.layer_table_name := 'arstidsbeite_var_grense';
	border_topo_info.layer_feature_column := 'grense';
	border_topo_info.snap_tolerance := 0.0000000001;
	border_topo_info.element_type = 2;
	
	
	surface_topo_info.topology_name := 'topo_rein_sysdata';
	surface_topo_info.layer_schema_name := 'topo_rein';
	surface_topo_info.layer_table_name := 'arstidsbeite_var_flate';
	surface_topo_info.layer_feature_column := 'omrade';
	surface_topo_info.snap_tolerance := 0.0000000001;
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);

	DROP TABLE IF EXISTS ttt_new_attributes_values;

	CREATE TEMP TABLE ttt_new_attributes_values(geom geometry,properties json);
	
	-- get json data
	INSERT INTO ttt_new_attributes_values(properties)
	SELECT 
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	--  
	IF (SELECT count(*) FROM ttt_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 

		-- TODO find another way to handle this
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt_new_attributes_values) );

		felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_linje);


	END IF;
	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.arstidsbeite_var_flate r
	SET 
		reindrift_sesongomrade_kode = (t2.properties->>'reindrift_sesongomrade_kode')::int,
		reinbeitebruker_id = (t2.properties->>'reinbeitebruker_id')::text,
		felles_egenskaper = topo_rein.get_rein_felles_egenskaper_update(felles_egenskaper, simple_sosi_felles_egenskaper_linje)
	FROM ttt_new_attributes_values t2
	WHERE id = (t2.properties->>'id')::int;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;

	RAISE NOTICE 'Number num_rows_affected  %',  num_rows_affected;
	

	
	RETURN num_rows_affected;

END;
$$ LANGUAGE plpgsql;


--UPDATE topo_rein.arstidsbeite_var_flate r
--SET reindrift_sesongomrade_kode = null;

-- select * from topo_update.apply_attr_on_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-39993,6527853],[-39980,6527867],[-39955,6527864],[-39973,6527837],[-40005,6527840],[-39993,6527853]]],"crs":{"type":"name","properties":{"name":"EPSG:32632"}}},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":2}}');

--select * from topo_update.apply_attr_on_topo_surface('{"type":"Feature","geometry":{"type":"Polygon","coordinates":[[[-40034,6527765],[-39904,6527747],[-39938,6527591],[-40046,6527603],[-40034,6527765]]]},"properties":{"reinbeitebruker_id":null,"reindrift_sesongomrade_kode":null}}');


-- SELECT * FROM topo_rein.arstidsbeite_var_flate;

