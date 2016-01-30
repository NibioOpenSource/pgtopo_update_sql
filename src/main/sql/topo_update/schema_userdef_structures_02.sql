

---------------------------------------------------------------------------------

-- A composite type to hold infor about the currrent layers that will be updated 
-- this will be used to pick up meta info from the topolgy layer doing a update
CREATE TYPE topo_update.input_meta_info 
AS (
	-- refferes to topology.topology
	topology_name varchar,
	
	-- reffers to topology.layer
	layer_schema_name varchar,
	layer_table_name varchar,
	layer_feature_column varchar,

	-- For a edge this is 2 and for a surface this is 3 
	element_type int,

	-- this is the snapp to tolerance used for snap to when adding new vector data 
	-- a typical value used for degrees is 0.0000000001
	snap_tolerance float8,
	
	-- this is computed by using function topo_update.get_topo_layer_id
	border_layer_id int
	

);



---------------------------------------------------------------------------------

-- A composite type to hold infor about the currrent layers that will be updated 
-- this will be used to pick up meta info from the topolgy layer doing a update
CREATE TYPE topo_update.json_input_structure 
AS (

-- the input geo picked from the client properties
input_geo geometry,

-- JSON that is sent from the client combained with the server json properties
json_properties json,

-- this build up based on the input json  this used for both line and  point
sosi_felles_egenskaper topo_rein.sosi_felles_egenskaper,

-- this only used for the surface objectand does not contain any info about drawing
sosi_felles_egenskaper_flate topo_rein.sosi_felles_egenskaper

);
