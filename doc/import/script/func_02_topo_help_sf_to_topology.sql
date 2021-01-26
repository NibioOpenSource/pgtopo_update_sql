-- This is script that copies small tables with simpla feature data into to a postgis topology table which are created on the fly.
-- This script is not created for performance but just to make easier to to get people in to test Postgis Topology om small datasets.

-- Ths scrip taks at minimum two parameters 
-- Parameters one is schema1.simple_feature_table1 used for input.
-- Parameter two is the schema2.topology_table_name for the result. 
-- More info about parameters further down.

-- Here is an example of calling it
-- "select topo_help_sf_to_topology_case_1('org_rein_sosi_dump.rein_konsesjonomr_flate','topo_test.rein_konsesjonomr_flate');"

-- The result of this file will two tables 
-- Table 1 : topo_test.rein_konsesjonomr_flate with the attributtes from table one and a topology column
-- Table 2 : topo_test.rein_konsesjonomr_flate_v with attributtes from table one and a geometry columns casted from the portgis topology column.

-- To check out the data use for instance qgis with Plugin: PostGIS Topology Editor from 

-- There are some shape files added here som you can test here is a example where I uses shp2pgsl to gether with this script.

-- # create schema if not exist
-- psql sl -c'CREATE SCHEMA IF NOT EXISTS test;'

-- # copy data from shape file to postgis
-- shp2pgsql -W ISO-8859-1 -d -D -s 4258 data/muni_surface.shp test.muni_surface | psql sl;

-- #copy data from simple feature to topology
-- psql sl -c "SELECT topo_help_sf_to_topology_case_1('test.muni_surface','test_topo.muni_surface');" 2>> /tmp/importfromtemp.log; 


-- To instal it 
-- git clone https://github.com/NibioOpenSource/pgtopo_update_sql
-- cd pgtopo_update_sql/src/test/sql/import
-- cat script/func_* | psql 

-- There are two things that needs to done to hanlde big tables 
-- Use https://github.com/larsop/content_balanced_grid/tree/master/func_grid to break things up
-- To get performance is to use postgres 9.6 and paralell functions


-- drop the old version if exits
drop FUNCTION IF EXISTS topo_help_sf_to_topology_case_1 (
in_table_simple_feature text,
in_table_topology_output text,
in_tolerance double precision,
append_data boolean,
primary_column_id text,
in_topology_schema_name text,
in_drop_topology_schema boolean,
in_drop_table_topology_output boolean
);


CREATE OR REPLACE FUNCTION topo_help_sf_to_topology_case_1(

-- the table with the orignal simple feauture data in this format 'schemaname.tablename'
in_table_simple_feature text,

-- the table that will be created with topology data on the fomat 'schemaname.tablename'
-- If the table already exixt it has by deleted before calling this script or set in_drop_table_topology_output to true
in_table_topology_output text,

-- the tolerance to be used adding new lines. The default is mostly used for degrees but for
-- meters try with something like 0.0000001
in_tolerance double precision default 0.0000000001,

-- Append data if in_table_topology_output exits
append_data boolean default true,

-- the new serial column in_table_topology_output
primary_column_id text default 'new_gid_id',

-- Drops a topology schema. This function should be USED WITH CAUTION, as it could destroy data you care about.
in_drop_topology_schema boolean default false,

-- Deletes the output topolofy table. This function should be USED WITH CAUTION, as it could destroy data you care about. 
in_drop_table_topology_output boolean default false,

-- the new schema name where we will put the topology_stuff, if not given it will use the schema from the 
-- topology table name in parameter 2 
in_topology_schema_name text  default null



)
  RETURNS text AS
$body$


-- This is a script that is used for testing of converting Simple Feauture to Postgis Topology

-- The system will create a view that casts from topology so you can compare the result the original table in a easy way
-- The geometry type of the input table

-- This is a script that takes the follwoing parameters
-- 1: name of the table top copy data from
-- 2: the name of schema where you want to store the result (the schem must not exits from before) 

DECLARE

------------- helper variables used for

-- the schema name from input table
table_schema_simple_feature text;

-- the table name from input table
table_name_simple_feature text;

-- the schema name for the table to be generated
table_schema_topology_output text;

-- the table name for the table to be generated
table_name_topology_output text;

-- the srid used for simple feature and topology
srid int;

-- The view name for the given Topology
topoology_view_name text;

-- the polygon geometry type
topo_geometry_type text;

-- the layer id for geomcolumn added or created
layer_id int;

-- this is a list of non geo colums name
non_geo_collumn_names text;

-- this is a list of non geo colums name
geo_collumn_name text;


------- tmp variables ----------
line_values VARCHAR[];
int_result int;

-- the topoid created or found
topology_id int;

-- used to to execte commands
command_string text;

-- used to get execute result from execte commands
command_result_text text;




BEGIN
	-- find schema and table name for simple feauture table
	SELECT string_to_array(in_table_simple_feature, '.') INTO line_values; 
	table_schema_simple_feature := line_values[1];
	table_name_simple_feature := line_values[2];

	-- find schema and table name for the topology out table
	SELECT string_to_array(in_table_topology_output, '.') INTO line_values; 
	table_schema_topology_output := line_values[1];
	table_name_topology_output := line_values[2];
	
	-- make topology view name
	topoology_view_name := in_table_topology_output || '_v';
	

	-- use default value for in_topology_name if not set
	IF (in_topology_schema_name is null) THEN
		in_topology_schema_name := table_schema_topology_output;
	END IF;

	RAISE NOTICE 'table_schema_simple_feature:% , table_name_simple_feature:% , in_topology_schema_name:%', table_schema_simple_feature, table_schema_simple_feature, in_topology_schema_name;

	
	
	-- Drop old topology is wanted ref from topology if true
	IF (in_drop_topology_schema = true) THEN
		-- check if exits
		command_string := format('SELECT id FROM topology.topology WHERE name like %L',in_topology_schema_name);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string INTO int_result;
		IF (int_result > 0) THEN
			command_string := format('SELECT DropTopology(%L)',in_topology_schema_name);
			RAISE NOTICE 'command_string %', command_string;
			EXECUTE command_string;
		END IF;
		
		command_string := format('DROP SCHEMA IF EXISTS %s CASCADE',in_topology_schema_name);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;

	END IF;
	
	-- Find no geo collumn names
	command_string := format('SELECT string_agg(quote_ident(update_column),%L) AS org_column_name
        FROM ( SELECT distinct(key) AS update_column
        	FROM  (SELECT * FROM %s limit 1) AS t, json_each_text(to_json((t))) 
        ) AS keys
		WHERE topo_help_get_feature_type(topo_help_get_data_type(%L,update_column)) IS NULL',
		',',
        in_table_simple_feature,
        in_table_simple_feature
		);
    RAISE NOTICE 'command_string %', command_string;
    EXECUTE command_string  INTO non_geo_collumn_names;
	RAISE NOTICE 'non_geo_collumn_names %', non_geo_collumn_names;
	
	-- Find geo collumn names -- usually omly one
	command_string := format('SELECT string_agg(quote_ident(update_column),%L) AS org_column_name
        FROM ( SELECT distinct(key) AS update_column
        	FROM  (SELECT * FROM %s limit 1) AS t, json_each_text(to_json((t))) 
        ) AS keys
		WHERE topo_help_get_feature_type(topo_help_get_data_type(%L,update_column)) IS NOT NULL',
		',',
        in_table_simple_feature,
        in_table_simple_feature
		);
    RAISE NOTICE 'command_string %', command_string;
    EXECUTE command_string  INTO geo_collumn_name;
	RAISE NOTICE 'geo_collumn_name %', geo_collumn_name;
	
	-- Find geom type
	command_string := format('SELECT topo_help_get_feature_type(topo_help_get_data_type(%L,%L))',
	in_table_simple_feature,
    geo_collumn_name);
    RAISE NOTICE 'command_string %', command_string;
    EXECUTE command_string  INTO topo_geometry_type;

    -- find srid
	command_string := format('SELECT Find_SRID(%L, %L, %L)',
	table_schema_simple_feature,
	table_name_simple_feature,
	geo_collumn_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string INTO srid;
	
	-- create topology schema it's not alreday exist
	command_string := format('SELECT id FROM topology.topology WHERE name like %L',in_topology_schema_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string INTO topology_id;
	
	IF (in_drop_topology_schema or topology_id is null) THEN
		command_string := format('SELECT CreateTopology(%L,%s,%s)',in_topology_schema_name, srid,in_tolerance);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string INTO topology_id;
	RAISE NOTICE 'Created new topology with id  %', topology_id;
	END IF;
	
	command_string := format('CREATE SCHEMA IF NOT EXISTS %s',in_topology_schema_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;

	command_string := format('CREATE SCHEMA IF NOT EXISTS %s',table_schema_topology_output);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;


	-- delete table if exits used for testing
	IF (append_data = false) THEN
		command_string := format('DROP TABLE IF EXISTS %s CASCADE',in_table_topology_output);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;
	END IF;

		-- drop old topo geom if exists
	command_string := format('SELECT topology_id FROM topology.layer WHERE schema_name like %L AND table_name like %L AND feature_column like %L',table_schema_topology_output,table_name_topology_output,geo_collumn_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string INTO int_result;
	IF (append_data = false and int_result > 0) THEN
		-- drop geomtry column
		-- DropTopoGeometryColumn(varchar schema_name, varchar table_name, varchar column_name);
		command_string := format('SELECT topology.DropTopoGeometryColumn(%L, %L, %L)',
		table_schema_topology_output,table_name_topology_output,geo_collumn_name);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string INTO command_result_text;
		RAISE NOTICE 'Delete TopoGeometryColumn with id  %', topology_id;
		
		command_string := format('DROP TABLE IF EXISTS %s CASCADE',in_table_topology_output);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;

	END IF;

	-- check again fix this in nocer way 
	command_string := format('SELECT layer_id FROM topology.layer WHERE topology_id = %L AND schema_name like %L AND table_name like %L AND feature_column like %L',
	topology_id,table_schema_topology_output,table_name_topology_output,geo_collumn_name);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string INTO layer_id;
	RAISE NOTICE 'found layer_id %', layer_id;

	IF (layer_id is null) THEN
		-- create table new topo table but with out geo column names
		command_string := format('CREATE TABLE %s AS (SELECT  %s FROM %s LIMIT 0)',in_table_topology_output, non_geo_collumn_names, in_table_simple_feature);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;
	
		-- add serial column
		command_string := format('ALTER TABLE %s ADD COLUMN %s serial PRIMARY KEY ',in_table_topology_output,primary_column_id);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string;

		-- add topology columns
		--integer AddTopoGeometryColumn(varchar topology_name, varchar schema_name, varchar table_name, varchar column_name, varchar feature_type);
		command_string := format('SELECT topology.AddTopoGeometryColumn(%L, %L, %L, %L, %L)',
		in_topology_schema_name,
		table_schema_topology_output,table_name_topology_output,
		geo_collumn_name,topo_geometry_type);
		RAISE NOTICE 'command_string %', command_string;
		EXECUTE command_string INTO layer_id;
		RAISE NOTICE 'Added TopoGeometryColumn with id  %', topology_id; 
	END IF;
	
	-- Copy data from simple featue
	command_string := format('INSERT INTO %s(%s,%s) SELECT %s, toTopoGeom(%s, %L, %s, %s) AS %s FROM %s sf',
	in_table_topology_output, non_geo_collumn_names,geo_collumn_name,non_geo_collumn_names,
	geo_collumn_name,
	in_topology_schema_name,layer_id, in_tolerance,
	geo_collumn_name,
	in_table_simple_feature);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;

	
	-- create a simple feature view 
	-- TODO remove geo view  geometry(POLYGON,4258)
	command_string := format('CREATE OR REPLACE VIEW  %s AS SELECT %s, %s, %s::geometry(%s,%s) FROM %s',
	topoology_view_name, primary_column_id, non_geo_collumn_names, geo_collumn_name, 
	topo_help_get_sf_multi_feature_type(topo_geometry_type),srid,
	in_table_topology_output);
	RAISE NOTICE 'command_string %', command_string;
	EXECUTE command_string;
	
	RETURN in_table_topology_output;

     
END
$body$
LANGUAGE 'plpgsql';


-- give all execute acess
GRANT EXECUTE ON FUNCTION topo_help_sf_to_topology_case_1 (
in_table_simple_feature text,
in_table_topology_output text,
in_tolerance double precision ,
append_data boolean ,
primary_column_id text,
in_drop_topology_schema boolean,
in_drop_table_topology_output boolean,
in_topology_schema_name text 
) to PUBLIC;


-- drop the old version if exits
drop FUNCTION IF EXISTS topo_help_sf_to_topology_case_1 (
in_table_simple_feature text,
in_table_topology_output text,
in_tolerance double precision ,
in_topology_schema_name text,
in_drop_topology_schema boolean,
in_drop_table_topology_output boolean
);



