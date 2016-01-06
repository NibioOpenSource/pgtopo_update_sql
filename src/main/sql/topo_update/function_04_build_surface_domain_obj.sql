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
not_null_fields text[];

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

	-- create the new topo object for the surfaces
	DROP TABLE IF EXISTS new_surface_data_for_edge; 
	CREATE TEMP TABLE new_surface_data_for_edge AS 
	(SELECT topo::topogeometry AS omrade, felles_egenskaper_flate AS felles_egenskape FROM topology.CreateTopoGeom( surface_topo_info.topology_name,surface_topo_info.element_type,surface_topo_info.border_layer_id,topoelementarray_data) as topo);

	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo surfaces added to table new_surface_data_for_edge   %',  num_rows_affected;


INSERT INTO topo_rein.arstidsbeite_var_flate (omrade,felles_egenskaper)
SELECT * FROM new_surface_data_for_edge;


	command_string := 'SELECT json_agg(row_to_json(t.*))::text FROM new_surface_data_for_edge AS t';

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;

