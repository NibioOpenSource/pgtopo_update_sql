-- This is a function that is used to build surface based on the border objects that alreday exits
-- topoelementarray_data is reffrerance to the egdes in this layer

-- DROP FUNCTION IF EXISTS topo_update.build_surface_domain_obj(json_feature text) cascade;


CREATE OR REPLACE FUNCTION topo_update.build_surface_domain_obj(
json_feature text,
topoelementarray_data topoelementarray, 
  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  border_layer_table text, border_layer_column text,
  snap_tolerance float8) 
RETURNS TABLE(result text) AS $$
DECLARE

json_result text;

-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;
surface_topo_info topo_update.input_meta_info ;

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

-- the orignal geo that is from the user
org_geo_in geometry;

geo_in geometry;

line_intersection_result geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];


BEGIN
	
	-- get meta data the border line for the surface
	border_topo_info := topo_update.make_input_meta_info(layer_schema, border_layer_table , border_layer_column );

	-- get meta data the surface 
	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );
	
	CREATE TEMP TABLE IF NOT EXISTS ttt2_new_attributes_values(geom geometry,properties json, felles_egenskaper topo_rein.sosi_felles_egenskaper);
	TRUNCATE TABLE ttt2_new_attributes_values;
	
	-- parse the json data to get properties and the new geometry
	INSERT INTO ttt2_new_attributes_values(properties)
	SELECT 
	properties
	FROM (
		SELECT 
			to_json(feat->'properties')::json  AS properties
		FROM (
		  	SELECT json_feature::json AS feat
		) AS f
	) AS e;

	-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	IF (SELECT count(*) FROM ttt2_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		-- get the felles egenskaper
		SELECT * INTO simple_sosi_felles_egenskaper_linje 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt2_new_attributes_values) );

		-- get felles_egenskaper both for sufcae and line
		felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);
		felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_linje);

	END IF;

	-- Create a temp table
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         surface_topo_info.layer_schema_name,
	         surface_topo_info.layer_table_name));
	EXECUTE command_string;


	
  	-- Insert all matching column names into temp table ttt2_new_topo_rows_in_org_table 
	INSERT INTO ttt2_new_topo_rows_in_org_table(reinbeitebruker_id,reindrift_sesongomrade_kode,felles_egenskaper,omrade)
		SELECT 
		reinbeitebruker_id,
		reindrift_sesongomrade_kode,
		felles_egenskaper_flate as felles_egenskaper,
		topology.CreateTopoGeom( surface_topo_info.topology_name,surface_topo_info.element_type,surface_topo_info.border_layer_id,topoelementarray_data) AS omrade
		FROM ttt2_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;
	RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';


	INSERT INTO topo_rein.arstidsbeite_var_flate(reinbeitebruker_id,reindrift_sesongomrade_kode,felles_egenskaper,omrade)
	SELECT reinbeitebruker_id,reindrift_sesongomrade_kode,felles_egenskaper,omrade FROM ttt2_new_topo_rows_in_org_table;


	command_string := 'SELECT json_agg(row_to_json(t.*))::text FROM ttt2_new_topo_rows_in_org_table AS t';

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

