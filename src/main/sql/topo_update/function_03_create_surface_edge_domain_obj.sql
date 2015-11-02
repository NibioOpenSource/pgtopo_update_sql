-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer first
-- After that will find the new surfaces created. 
-- new surfaces that was part old serface should inherit old values

-- The result is a set of id's of the new surface objects created

-- TODO set attributtes for the line
-- TODO set attributtes for the surface


-- DROP FUNCTION FUNCTION topo_update.create_surface_edge_domain_obj(geo_in geometry) cascade;


CREATE OR REPLACE FUNCTION topo_update.create_surface_edge_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

new_border_data topogeometry;

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- this is the tolerance used for snap to 
snap_tolerance float8 = 0.0000000001;

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

	
	DROP TABLE IF EXISTS new_attributes_values;

	CREATE TEMP TABLE new_attributes_values(geom geometry,properties json);
	
	-- parse the json data
	INSERT INTO new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')::json  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

	-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	IF (SELECT count(*) FROM new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	ELSE 
		SELECT geom FROM new_attributes_values INTO geo_in;
	END IF;


	org_geo_in := geo_in;
	

	
	RAISE NOTICE 'The input as it used before check/fixed %',  ST_AsText(geo_in);

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t0; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t0(geo_in geometry, IsSimple boolean, IsClosed boolean);
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;
	
	IF NOT ST_IsSimple(geo_in) THEN
		-- This is probably a crossing line so we try to build a surface
		BEGIN
			line_intersection_result := ST_BuildArea(ST_UnaryUnion(geo_in))::geometry;
			RAISE NOTICE 'Line intersection result is %', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(line_intersection_result);
		EXCEPTION WHEN others THEN
		 	RAISE NOTICE 'Error code: %', SQLSTATE;
      		RAISE NOTICE 'Error message: %', SQLERRM;
			RAISE NOTICE 'Failed to to use line intersection result is %, try buffer', ST_AsText(line_intersection_result);
			geo_in := ST_ExteriorRing(ST_Buffer(line_intersection_result,0.00000000001));
		END;
		
		-- check the object after a fix
		RAISE NOTICE 'Fixed a non simple line to be valid simple line by using by buildArea %',  geo_in;
	ELSIF NOT ST_IsClosed(geo_in) THEN
		-- If this is not closed just check that it intersects two times with a exting border
		-- TODO make more precice check that only used edges that in varbeite surface
		-- TODO handle return of gemoerty collection
		-- thic code fails need to make a test on this 
		-- num_edge_intersects :=  (SELECT ST_NumGeometries(ST_Intersection(geo_in,e.geom)) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(geo_in,e.geom))::int;
		line_intersection_result := (select ST_Union(ST_Intersection(geo_in,e.geom)) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(geo_in,e.geom))::geometry;

		RAISE NOTICE 'Line intersection result is %', ST_AsText(line_intersection_result);

		num_edge_intersects :=  (SELECT ST_NumGeometries(line_intersection_result))::int;
		
		RAISE NOTICE 'Found a non closed linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		IF num_edge_intersects is null OR num_edge_intersects < 2 THEN
			geo_in := ST_ExteriorRing(ST_BuildArea(ST_UnaryUnion(ST_AddPoint(geo_in, ST_StartPoint(geo_in)))));
		ELSEIF num_edge_intersects > 2 THEN
			RAISE EXCEPTION 'Found a non valid linestring does intersect % times, with any borders by using buildArea %', num_edge_intersects, geo_in;
		END IF;
	END IF;

	IF add_debug_tables = 1 THEN
		INSERT INTO topo_rein.create_surface_edge_domain_obj_t0(geo_in,IsSimple,IsClosed) VALUES(geo_in,St_IsSimple(geo_in),St_IsSimple(geo_in));
	END IF;

	RAISE NOTICE 'The input as it used after check/fixed %',  ST_AsText(geo_in);
	
	IF geo_in IS NULL THEN
		RAISE EXCEPTION 'The geo generated from geo_in is null %', org_geo_in;
	END IF;
	

	-- create the new topo object for the egde layer
	new_border_data := topo_update.create_surface_edge(geo_in);
	RAISE NOTICE 'The new topo object created for based on the input geo  %',  new_border_data;

	-- TODO insert some correct value for attributes
	INSERT INTO topo_rein.arstidsbeite_var_grense(grense, felles_egenskaper)
	SELECT new_border_data, topo_rein.get_rein_felles_egenskaper_linje(0);

	-- create the new topo object for the surfaces
	DROP TABLE IF EXISTS new_surface_data_for_edge; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE new_surface_data_for_edge AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.create_edge_surfaces(new_border_data,geo_in));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of topo surfaces added to table new_surface_data_for_edge   %',  num_rows_affected;
	
	-- clean up old surface and return a list of the objects
	DROP TABLE IF EXISTS res_from_update_domain_surface_layer; 
	CREATE TEMP TABLE res_from_update_domain_surface_layer AS 
	(SELECT topo::topogeometry AS surface_topo FROM topo_update.update_domain_surface_layer('new_surface_data_for_edge'));
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number_of_rows removed from topo_update.update_domain_surface_layer   %',  num_rows_affected;

	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t1; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t1 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM new_surface_data_for_edge);

		-- get the reslt from topo_update.update_domain_surface_layer
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t2; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t2 AS 
		(SELECT surface_topo::geometry AS geo , surface_topo::text AS topo FROM res_from_update_domain_surface_layer);
		
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.create_surface_edge_domain_obj_t1_p; 
		CREATE TABLE topo_rein.create_surface_edge_domain_obj_t1_p AS 
		(SELECT ST_PointOnSurface(surface_topo::geometry) AS geo , surface_topo::text AS topo FROM new_surface_data_for_edge);

	END IF;
	
	IF ST_IsClosed(geo_in) THEN 
		command_string := format('SELECT tg.id AS id FROM ' || 
		surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name || 
		' tg, new_surface_data_for_edge new ' || 
		'WHERE (new.surface_topo).id = (tg.omrade).id AND ' || 
		'ST_intersects(ST_PointOnSurface((new.surface_topo)::geometry), ST_MakePolygon(%1$L))',geo_in);
    	RAISE NOTICE 'A closed objects only return objects in %', command_string;
  	ELSE	
		command_string := 'SELECT tg.id AS id FROM ' || 
		surface_topo_info.layer_schema_name || '.' || surface_topo_info.layer_table_name || ' tg, new_surface_data_for_edge new ' || 
		'WHERE (new.surface_topo).id = (tg.omrade).id';
	END IF;

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;






--select topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[17.6330443809,68.8115601041],[17.6387976939,68.8139696266],[17.651108675,68.8197978913],[17.656025567,68.824150941],[17.6590891423,68.8313725882],[17.6687283401,68.8383774222],[17.6769272947,68.8438141691],[17.6799702895,68.8455836959],[17.6814446398,68.8473778381],[17.6826056791,68.8491769151],[17.6754309279,68.8574683255],[17.6768111517,68.8610813808],[17.6786277098,68.8630973426],[17.6832969617,68.8626829344],[17.7042335545,68.8576840007],[17.7046971661,68.8575732259],[17.7228715239,68.8544433714],[17.730265313,68.8531888918],[17.7474299065,68.8521172703],[17.7580904888,68.8493319729],[17.7620430258,68.8482454132],[17.766382225,68.8452214242],[17.768595013,68.8427999761],[17.770677753,68.8418571938],[17.7993786344,68.8351390002],[17.8015295769,68.8322636927],[17.8106875204,68.8251829742],[17.8126349738,68.8207204137],[17.813172856,68.8194877452],[17.8092516038,68.8165818383],[17.8057166741,68.8135434408],[17.8020711296,68.8107631741],[17.7970500987,68.8082352217],[17.7936961319,68.8060259166],[17.7921794833,68.8032686653],[17.7906110372,68.8029084861],[17.7873798056,68.8021663877],[17.7816156088,68.801238587],[17.775637664,68.8011092992],[17.7675951582,68.80203588],[17.7629966096,68.8029059351],[17.7538686924,68.8052126319],[17.7470904936,68.8062312333],[17.7361419258,68.8065217482],[17.7275735719,68.8057509517],[17.7161318666,68.804571385],[17.7014350923,68.802420569],[17.6840600634,68.8014467869],[17.6714791494,68.8011909846],[17.6588292621,68.8029798853],[17.6477569978,68.8048568386],[17.6345707718,68.8074473805],[17.6312458927,68.8085211733],[17.6314338873,68.8101084381],[17.6325214593,68.8113410461],[17.6330443809,68.8115601041]]}}');
--select topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[17.6330443809,68.8115601041],[17.6325214593,68.8113410461],[17.6314338873,68.8101084381],[17.6312458927,68.8085211733],[17.6345707718,68.8074473805],[17.6477569978,68.8048568386],[17.6588292621,68.8029798853],[17.6714791494,68.8011909846],[17.6840600634,68.8014467869],[17.7014350923,68.802420569],[17.7161318666,68.804571385],[17.7275735719,68.8057509517],[17.7361419258,68.8065217482],[17.7470904936,68.8062312333],[17.7538686924,68.8052126319],[17.7629966096,68.8029059351],[17.7675951582,68.80203588],[17.775637664,68.8011092992],[17.7816156088,68.801238587],[17.7873798056,68.8021663877],[17.7906110372,68.8029084861],[17.7921794833,68.8032686653],[17.7917898184,68.802559933],[17.7936081288,68.7995863939],[17.7991122281,68.7968530268],[17.8053713195,68.7950675418],[17.8100721409,68.7937643568],[17.8110865684,68.791188632],[17.8088921375,68.789028367],[17.807761702,68.7858883709],[17.8048773851,68.7866560155],[17.8021466009,68.7873827419],[17.7946362762,68.7875066805],[17.789415962,68.7883877547],[17.7826578664,68.7920202692],[17.7796552384,68.7930919024],[17.7644865146,68.7947029331],[17.7365213125,68.7968603058],[17.7223353221,68.7962933685],[17.6915155806,68.795649264],[17.6512357905,68.7971922411],[17.6408727751,68.7997392014],[17.6293084136,68.802758363],[17.6147820645,68.8072990719],[17.6149154953,68.8084328476],[17.6201283957,68.810056162],[17.6275353078,68.811645469],[17.630355107,68.8116017977],[17.6330443809,68.8115601041]]}}');
--select topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[17.813172856,68.8194877452],[17.8126349738,68.8207204137],[17.8106875204,68.8251829742],[17.8015295769,68.8322636927],[17.7993786344,68.8351390002],[17.770677753,68.8418571938],[17.768595013,68.8427999761],[17.766382225,68.8452214242],[17.7620430258,68.8482454132],[17.7580904888,68.8493319729],[17.7474299065,68.8521172703],[17.730265313,68.8531888918],[17.7228715239,68.8544433714],[17.7046971661,68.8575732259],[17.7042335545,68.8576840007],[17.7147710788,68.8576398677],[17.7921111021,68.8572962096],[17.8044096866,68.855049081],[17.8153782512,68.8522550314],[17.823905621,68.8500688402],[17.8342512116,68.8448983379],[17.8410458017,68.8414904818],[17.8448121233,68.8365426713],[17.8451680131,68.8360751345],[17.8406428369,68.8355121756],[17.8339440802,68.8326580248],[17.8300690274,68.8298741997],[17.8278008371,68.8271472124],[17.8257342588,68.8244060754],[17.8210512689,68.8224239254],[17.8136273422,68.8198245502],[17.813172856,68.8194877452]]}}');





