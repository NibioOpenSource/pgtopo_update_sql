

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
	snap_tolerance float8
	

);
