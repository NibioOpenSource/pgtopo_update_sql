
-- This is a common method to parse all input data
-- It returns a struture that is adjusted reindrift that depends on sosi felles eganskaper


DROP FUNCTION IF EXISTS topo_update.handle_input_json_props(json, json, int,boolean) ;
DROP FUNCTION IF EXISTS topo_update.handle_input_json_props(json, json, int) ;

CREATE OR REPLACE FUNCTION  topo_update.handle_input_json_props(client_json_feature json,  server_json_feature json, srid_out int) 
RETURNS topo_update.json_input_structure AS $$DECLARE

DECLARE 
use_default_dates boolean = true;
BEGIN
return  topo_update.handle_input_json_props(client_json_feature,  server_json_feature, srid_out, use_default_dates); 
END;
$$ LANGUAGE plpgsql IMMUTABLE;



-- This is a common method to parse all input data
-- It returns a struture that is adjusted reindrift that depends on sosi felles eganskaper

CREATE OR REPLACE FUNCTION  topo_update.handle_input_json_props(client_json_feature json,  server_json_feature json, srid_out int, use_default_dates boolean) 
RETURNS topo_update.json_input_structure AS $$DECLARE

DECLARE 
-- holds the value for felles egenskaper from input
simple_sosi_felles_egenskaper topo_rein.simple_sosi_felles_egenskaper;

-- JSON that is sent from the cleint
client_json_properties json;

-- JSON produced on the server side
server_json_properties json;

-- Keys in the server JSON properties
server_json_keys text;
keys_to_set   TEXT[];
values_to_set json[];

-- holde the computed value for json input reday to use
json_input_structure topo_update.json_input_structure;  

BEGIN

	RAISE NOTICE 'client_json_feature %, server_json_feature % use_default_dates %',  client_json_feature, server_json_feature , use_default_dates;
	
	-- geth the geometry may be null
	json_input_structure.input_geo := topo_rein.get_geom_from_json(client_json_feature::json,srid_out);

	-- get json from the client
	client_json_properties := to_json(client_json_feature::json->'properties');
	RAISE NOTICE 'client_json_properties %',  client_json_properties ;
	
	-- get the json from the serrver, may be null
	IF server_json_feature IS NOT NULL THEN
		server_json_properties := to_json(server_json_feature::json->'properties');
	  	RAISE NOTICE 'server_json_properties  % ',  server_json_properties ;
	
		-- overwrite client JSON properties with server property values
	  	SELECT array_agg("key"),array_agg("value")  INTO keys_to_set,values_to_set
		FROM json_each(server_json_properties) WHERE "value"::text != 'null';
		client_json_properties := topo_update.json_object_set_keys(client_json_properties, keys_to_set, values_to_set);
		RAISE NOTICE 'json_properties after update  %',  client_json_properties ;
	END IF;

	json_input_structure.json_properties := client_json_properties;
	
	-- This maps from the simple format used on the client 
	-- Because the client do not support Postgres user defined types like we have used in  topo_rein.sosi_felles_egenskaper;
	-- First append the info from the client properties, only properties that maps to valid names in topo_rein.simple_sosi_felles_egenskaper will be used.
	simple_sosi_felles_egenskaper := json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,client_json_properties );

	RAISE NOTICE 'felles_egenskaper_sosi point/line before  %',  simple_sosi_felles_egenskaper;

	-- Here we map from simple properties to topo_rein.sosi_felles_egenskaper for line an point objects
	json_input_structure.sosi_felles_egenskaper := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper,use_default_dates);
	
	RAISE NOTICE 'felles_egenskaper_sosi point/line after  %',  json_input_structure.sosi_felles_egenskaper;
	
	-- Here we get info for the surface objects
   	json_input_structure.sosi_felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper,use_default_dates);
	

	RETURN json_input_structure;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


