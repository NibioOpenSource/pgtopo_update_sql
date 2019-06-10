--But when we are using degrees things starts be more difficult. The reason why we are using degrees is to get a accurate  transformations to local UTM zones which are different depending on where in Norway you are.

--So the problem is how to use tolerances so we get a behavior equal to the test using meter. 

-- THIS is test is based on commmets from strk https://lists.osgeo.org/pipermail/postgis-users/2019-June/043384.html

--We can we define the layer in Postgis Topology with quite big value because this is just max value as it seems. So we can adjust the tolerance parameter as we add lines but the problem is that we need to adjust this parameter depending on where we are and what orientation the line has.  For vertical lines we need a bigger tolerance than for horizontal lines in Norway. This makes it quite complicated to handle adding new lines. 

--The code :https://github.com/NibioOpenSource/pgtopo_update_sql/blob/develop/src/test/sql/snapto/snapto_code_example_degrees_st_min_tolerance.sql

--A image of the result :https://github.com/NibioOpenSource/pgtopo_update_sql/blob/develop/src/test/sql/snapto/snapto_code_example_degrees_st_min_tolerance.png


DROP schema if exists test_topo_snap_03_layers cascade;
select topology.droptopology('test_topo_snap_03');

DO
$body$
DECLARE 
-- north/west Norway
x_start real := 1108142.0; 
y_start real := 7788000.0;	
-- south/east Norway	
--x_start real := -100000.0; 
--y_start real := 6442000.0;	

delta real := 1.0;
line_length int := 10.0;
num_lines int := 4.0;
counter INTEGER := 0 ;
x real;
y real;
new_line geometry;
srid_used_in_layer int = 4258;
layer_precision real := 0.00017; -- somthing close to 10 meter a place i Norway ???

add_line_layer_precision_vertical real := layer_precision/5.0;
add_line_layer_precision_horizontal real := layer_precision/10.0;

add_line_layer_st_mintolerance real ;
add_line_layer_st_min_x_factor_vertical real := 1000.0;
add_line_layer_st_min_x_factor_horizontal real := 500.0;

srid_meter_create int = 25833;

BEGIN

	
perform CreateTopology('test_topo_snap_03',srid_used_in_layer,layer_precision);
CREATE schema test_topo_snap_03_layers;

CREATE TABLE test_topo_snap_03_layers.test_line_a(
id serial PRIMARY KEY NOT NULL
);

execute format('CREATE TABLE test_topo_snap_03_layers.test_line_no_snap(
id serial PRIMARY KEY NOT NULL,
geom geometry(LineString,%s))',srid_used_in_layer);

-- add a topogeometry column to get a ref to the borders
perform topology.AddTopoGeometryColumn('test_topo_snap_03', 'test_topo_snap_03_layers', 'test_line_a', 'line', 'LINESTRING') As new_layer_id;

	WHILE counter < num_lines LOOP
      counter := counter + 1 ; 
      -- make lines east - west , horizontal
      x := x_start;
      y := y_start + (counter*delta);
      new_line := ST_setSrid(ST_MakeLine(ST_MakePoint(x,y), ST_MakePoint(x+line_length,y)),srid_meter_create);
      RAISE NOTICE 'topology._st_mintolerance(new_line) : %', topology._st_mintolerance(new_line);
      add_line_layer_st_mintolerance := topology._st_mintolerance(new_line)*add_line_layer_st_min_x_factor_horizontal;
      
      execute format('select ST_Transform(%L::Geometry,%s)',new_line,srid_used_in_layer) into new_line;
      insert into test_topo_snap_03_layers.test_line_no_snap(geom) values(new_line);
      perform topology.toTopoGeom(new_line, 'test_topo_snap_03', 1, add_line_layer_st_mintolerance);
      
      
      -- make lines east - west , vertical
      x := x_start + 20 + (counter*delta);
      y := y_start + 20;
      new_line := ST_setSrid(ST_MakeLine(ST_MakePoint(x,y), ST_MakePoint(x,y+line_length)),srid_meter_create);
	  RAISE NOTICE 'topology._st_mintolerance(new_line) : %', topology._st_mintolerance(new_line);
      add_line_layer_st_mintolerance := topology._st_mintolerance(new_line)*add_line_layer_st_min_x_factor_vertical;
      
      execute format('select ST_Transform(%L::Geometry,%s)',new_line,srid_used_in_layer) into new_line;
      insert into test_topo_snap_03_layers.test_line_no_snap(geom) values(new_line);
      perform topology.toTopoGeom(new_line, 'test_topo_snap_03', 1, add_line_layer_st_mintolerance);
      
   END LOOP ; 
END
$body$;
