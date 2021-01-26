--First we show that this works well when working in meter. I create a Postgis Topology layer with layer_precision 10 meter using https://epsg.io/25833. Then we add 4 horizontal lines and 4 vertical lines using a precision with 2 meter. Postgis Topology handles this nicely and we end with total of 4 lines and not 8 lines as we added, because every second line snaps to the line added before because the distance between the lines are less 2 meter which use as precision we used when adding new lines. 

--The code:https://github.com/NibioOpenSource/pgtopo_update_sql/blob/develop/src/test/sql/snapto/snapto_code_example_meter.sql

--A image of the result:https://github.com/NibioOpenSource/pgtopo_update_sql/blob/develop/src/test/sql/snapto/snapto_code_example_meter.png
--The green lines are the lines we added, the red lines are the lines that are stored in the edge table.


--DROP schema if exists test_topo_snap_01_layers cascade;
--select topology.droptopology('test_topo_snap_01');

DO
$body$
DECLARE 
-- north/west Norway
--x_start real := 1108142.0; 
--y_start real := 7788000.0;	
-- south/east Norway	
x_start real := -100000.0; 
y_start real := 6442000.0;	
delta real := 1.0;
line_length int := 10.0;
num_lines int := 4;
counter INTEGER := 0 ;
x real;
y real;
new_line geometry;
srid_used_in_layer int = 25833;
layer_precision real := 10.0;
add_line_layer_precision real := layer_precision/5.0;

srid_meter_create int = 25833;

BEGIN
	
perform CreateTopology('test_topo_snap_01',srid_used_in_layer,layer_precision);
CREATE schema test_topo_snap_01_layers;

CREATE TABLE test_topo_snap_01_layers.test_line_a(
id serial PRIMARY KEY NOT NULL
);

execute format('CREATE TABLE test_topo_snap_01_layers.test_line_no_snap(
id serial PRIMARY KEY NOT NULL,
geom geometry(LineString,%s))',srid_used_in_layer);

-- add a topogeometry column to get a ref to the borders
perform topology.AddTopoGeometryColumn('test_topo_snap_01', 'test_topo_snap_01_layers', 'test_line_a', 'line', 'LINESTRING') As new_layer_id;

	WHILE counter < num_lines LOOP
      counter := counter + 1 ; 
      -- make lines east - west , horizontal
      x := x_start;
      y := y_start + (counter*delta);
      new_line := ST_setSrid(ST_MakeLine(ST_MakePoint(x,y), ST_MakePoint(x+line_length,y)),srid_meter_create);
      execute format('select ST_Transform(%L::Geometry,%s)',new_line,srid_used_in_layer) into new_line;
      insert into test_topo_snap_01_layers.test_line_no_snap(geom) values(new_line);
      perform topology.toTopoGeom(new_line, 'test_topo_snap_01', 1, add_line_layer_precision);
      
      -- make lines east - west , vertical
      x := x_start + 20 + (counter*delta);
      y := y_start + 20;
      new_line := ST_setSrid(ST_MakeLine(ST_MakePoint(x,y), ST_MakePoint(x,y+line_length)),srid_meter_create);
      execute format('select ST_Transform(%L::Geometry,%s)',new_line,srid_used_in_layer) into new_line;
      insert into test_topo_snap_01_layers.test_line_no_snap(geom) values(new_line);
      perform topology.toTopoGeom(new_line, 'test_topo_snap_01', 1, add_line_layer_precision);
      
   END LOOP ; 
   
   
END
$body$;

