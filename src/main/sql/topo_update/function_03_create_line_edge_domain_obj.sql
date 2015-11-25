
-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_as(tblname text,qry text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_as(tblname text,qry text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||' ON COMMIT DROP AS '||$2||'';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname = substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||' AS '||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}

-- TODO move this function to it's file

-- DROP function topo_update.create_temp_tbl_def(tblname text,def text);
-- {
CREATE OR replace function topo_update.create_temp_tbl_def(tblname text,def text)
returns text as
$$ 
BEGIN
$1 = trim($1);
IF NOT EXISTS (SELECT relname FROM pg_catalog.pg_class where relname =$1) THEN
	return 'CREATE TEMP TABLE '||$1||''||$2||' ON COMMIT DROP';
--IF NOT EXISTS (SELECT 1 FROM pg_tables where tablename = substr($1,strpos($1,'.')+1) AND schemaname=substr($1,0,strpos($1,'.')) ) THEN
--	return 'CREATE TABLE '||$1||''||$2||'';
else
	return 'TRUNCATE TABLE '||$1||'';
END IF;
END
$$
language plpgsql;
--}


--DO $$
--DECLARE 
--command_string text;
--BEGIN
--	command_string := topo_update.create_temp_tbl_def('ttt2_new_attributes_values','(geom geometry,properties json)');
--	RAISE NOTICE 'command_string %',  command_string;
--	EXECUTE command_string;
--END $$;

-- This a function that will be called from the client when user is drawing a line
-- This line will be applied the data in the line layer

-- The result is a set of id's of the new line objects created

-- TODO set attributtes for the line


-- {
CREATE OR REPLACE FUNCTION
topo_update.create_line_edge_domain_obj(json_feature text,
  layer_schema text, layer_table text, layer_column text,
  snap_tolerance float8)
RETURNS TABLE(id integer) AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this is the tolerance used for snap to 
-- TODO use as parameter put for testing we just have here for now
border_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- the number times the input line intersects
num_edge_intersects int;

input_geo geometry;

-- holds the value for felles egenskaper from input
felles_egenskaper_linje topo_rein.sosi_felles_egenskaper;
simple_sosi_felles_egenskaper_linje topo_rein.simple_sosi_felles_egenskaper;

BEGIN
	
	
	-- Read parameters
	border_topo_info.layer_schema_name := layer_schema;
	border_topo_info.layer_table_name := layer_table;
	border_topo_info.layer_feature_column := layer_column;
	border_topo_info.snap_tolerance := snap_tolerance;

	-- Find out topology name and element_type from layer identifier
	SELECT t.name, l.feature_type
	FROM topology.topology t, topology.layer l
	WHERE l.level = 0 -- need be primitive
    AND l.schema_name = border_topo_info.layer_schema_name
	  AND l.table_name = border_topo_info.layer_table_name
	  AND l.feature_column = border_topo_info.layer_feature_column
	  AND t.id = l.topology_id
	INTO STRICT border_topo_info.topology_name,
	            border_topo_info.element_type;

		-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);

	
	RAISE NOTICE 'The JSON input %',  json_feature;

	RAISE NOTICE 'border_layer_id %', border_layer_id;


	-- get the json values
	command_string := topo_update.create_temp_tbl_def('ttt2_new_attributes_values','(geom geometry,properties json)');
	RAISE NOTICE 'command_string %', command_string;

	EXECUTE command_string;

	-- TRUNCATE TABLE ttt2_new_attributes_values;
	INSERT INTO ttt2_new_attributes_values(geom,properties)
	SELECT 
		topo_rein.get_geom_from_json(feat,4258) as geom,
		to_json(feat->'properties')  as properties
	FROM (
	  	SELECT json_feature::json AS feat
	) AS f;

		-- check that it is only one row put that value into 
	-- TODO rewrite this to not use table in
	
	RAISE NOTICE 'Step::::::::::::::::: 1';

	IF (SELECT count(*) FROM ttt2_new_attributes_values) != 1 THEN
		RAISE EXCEPTION 'Not valid json_feature %', json_feature;
	END IF;

	-- TODO find another way to handle this
	SELECT * INTO simple_sosi_felles_egenskaper_linje
	FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
	(select properties from ttt2_new_attributes_values) );

	felles_egenskaper_linje := topo_rein.get_rein_felles_egenskaper(simple_sosi_felles_egenskaper_linje);

	SELECT geom INTO input_geo FROM ttt2_new_attributes_values;
	

	RAISE NOTICE 'Step::::::::::::::::: 2';

	-- Create temporary table to receive the new record
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	         border_topo_info.layer_schema_name,
	         border_topo_info.layer_table_name));
	EXECUTE command_string;

  -- Insert all matching column names into temp table
	INSERT INTO ttt2_new_topo_rows_in_org_table
		SELECT r.* --, t2.geom
		FROM ttt2_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r;

  RAISE NOTICE 'Added all attributes to ttt2_new_topo_rows_in_org_table';

  -- Convert geometry to TopoGeometry, write it in the temp table
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET %I = topology.toTopoGeom(%L, %L, %L, %L)',
    border_topo_info.layer_feature_column, input_geo,
    border_topo_info.topology_name, border_layer_id,
    border_topo_info.snap_tolerance);
	EXECUTE command_string;

  RAISE NOTICE 'Converted to TopoGeometry';

  -- Add the common felles_egenskaper field
  command_string := format('UPDATE ttt2_new_topo_rows_in_org_table
    SET felles_egenskaper = %L', felles_egenskaper_linje);
	EXECUTE command_string;

  RAISE NOTICE 'Set felles_egenskaper field';

  -- Extract name of fields with not-null values:
  SELECT array_to_string(array_agg(quote_ident(key)),',')
    FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))
   WHERE value IS NOT NULL
    INTO command_string;

  RAISE NOTICE 'Extract name of not-null fields: %', command_string;

  -- Copy full record from temp table to actual table and
  -- update temp table with actual table values
  command_string := format(
    'WITH inserted AS ( INSERT INTO %I.%I (%s) SELECT %s FROM
ttt2_new_topo_rows_in_org_table RETURNING * ), deleted AS ( DELETE
FROM ttt2_new_topo_rows_in_org_table ) INSERT INTO
ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
    border_topo_info.layer_schema_name,
    border_topo_info.layer_table_name,
    command_string, command_string);
	EXECUTE command_string;

	RAISE NOTICE 'Step::::::::::::::::: 3';

	-- SELECT ST_AsText(ST_Intersection(nr2.linje,a.linje)::geometry) FROM topo_rein.reindrift_anlegg_linje  a, ttt2_new_topo_rows_in_org_table nr2 WHERE	a.id != nr2.id;
	-- IF I use the abouve I get "mvn clean install -Dtest=Test_AddData_3_RAN_L#addLinesCase3"
	--                st_astext                 
	-- GEOMETRYCOLLECTION EMPTY
 	-- GEOMETRYCOLLECTION EMPTY
 	--..
 	--..
 	-- POINT(17.0907328274024 68.7282948978786)
 	-- 
	-- So I use this instead
	SELECT count(distinct a.id) INTO  num_edge_intersects
    FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.edge_data ed,
	topo_rein.reindrift_anlegg_linje  a,
	ttt2_new_topo_rows_in_org_table nr2,
	topo_rein_sysdata.relation re2,
	topo_rein_sysdata.edge_data ed2
	
	WHERE 
	(a.linje).id = re.topogeo_id AND
	re.layer_id = border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id AND
	(nr2.linje).id = re2.topogeo_id and
	re2.layer_id = border_layer_id and 
	re2.element_type = 2 and  -- todo use variable element_type_edge=2
	ed2.edge_id = re2.element_id and
	(ed2.start_node = ed.start_node or
	ed2.end_node = ed.end_node or
	ed2.start_node = ed.end_node or
	ed2.start_node = ed.end_node) AND
	(a.linje).id != (nr2.linje).id;
	

	RAISE NOTICE 'num_object_intersects::::::::::::::::: %', num_edge_intersects;
	

	
	--------------------- Start: code to remove duplicate edges ---------------------
	-- Should be moved to a separate proc so we could reuse this code for other line 
	
	-- Find the edges that are used by the input line 
	command_string := topo_update.create_temp_tbl_as('ttt2_covered_by_input_line','SELECT * FROM  topo_rein_sysdata.edge_data limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_covered_by_input_line;
	INSERT INTO ttt2_covered_by_input_line
	SELECT distinct ed.*  
    FROM 
	topo_rein_sysdata.relation re,
	ttt2_new_topo_rows_in_org_table ud, 
	topo_rein_sysdata.edge_data ed
	WHERE 
	(ud.linje).id = re.topogeo_id AND
	re.layer_id = border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id = re.element_id;

	RAISE NOTICE 'Step::::::::::::::::: 4 ny';

	-- Find edges that are not used by the input line which needs to recreated.
	-- This only the case when ypu have direct overlap. Will only happen when part of the same line is added twice.
	-- Exlude the object createed now
	command_string := topo_update.create_temp_tbl_as('ttt2_not_covered_by_input_line','SELECT * FROM  topo_rein_sysdata.edge_data limit 0');
	EXECUTE command_string;
	INSERT INTO ttt2_not_covered_by_input_line
	SELECT distinct ed.*  
    FROM 
	ttt2_new_topo_rows_in_org_table ud, 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.relation re2,
	topo_rein_sysdata.relation re3,
	topo_rein_sysdata.edge_data ed
	WHERE 
	(ud.linje).id = re.topogeo_id AND
	re.layer_id = border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	re2.layer_id = border_layer_id AND 
	re2.element_type = 2 AND  -- TODO use variable element_type_edge=2
	re2.element_id = re.element_id AND
	re3.topogeo_id = re2.topogeo_id AND
	re3.element_id = ed.edge_id AND
	NOT EXISTS (SELECT 1 FROM ttt2_covered_by_input_line where ed.edge_id = edge_id);


	RAISE NOTICE 'Step::::::::::::::::: 5 cb %' , (select count(*) from ttt2_not_covered_by_input_line);

	-- Find topo objects that needs to be adjusted because old topo object has edges that are used by this new topo object
	-- Exlude the object createed now
	command_string := topo_update.create_temp_tbl_as('ttt2_affected_objects_id','SELECT * FROM  topo_rein.reindrift_anlegg_linje limit 0');
	EXECUTE command_string;
	INSERT INTO ttt2_affected_objects_id
	SELECT distinct a.*  
    FROM 
	topo_rein_sysdata.relation re1,
	topo_rein_sysdata.relation re2,
	ttt2_new_topo_rows_in_org_table ud, 
	topo_rein.reindrift_anlegg_linje a
	WHERE 
	(ud.linje).id = re1.topogeo_id AND
	re1.layer_id = border_layer_id AND 
	re1.element_type = 2 AND
	re1.element_id = re2.element_id AND 
	(a.linje).id = re2.topogeo_id AND
	re2.layer_id = border_layer_id AND 
	re2.element_type = 2 AND
	NOT EXISTS (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr where a.id = nr.id);
	
	RAISE NOTICE 'Step::::::::::::::::: 6 af %' , (select count(*) from ttt2_affected_objects_id);


	-- Find topo objects thay can deleted because all their edges area covered by new input linje
	-- This is true this objects has no edges in the list of not used edges
	command_string := topo_update.create_temp_tbl_as('ttt2_objects_to_be_delted','SELECT * FROM  topo_rein.reindrift_anlegg_linje limit 0');
	EXECUTE command_string;
	INSERT INTO ttt2_objects_to_be_delted
	SELECT b.id FROM 
	ttt2_affected_objects_id b,
	ttt2_covered_by_input_line c,
	topo_rein_sysdata.relation re2
	WHERE b.id NOT IN
	(	
		SELECT distinct a.id 
		FROM 
		topo_rein_sysdata.relation re1,
		ttt2_affected_objects_id a,
		ttt2_not_covered_by_input_line ued1
		WHERE 
		(a.linje).id = re1.topogeo_id AND
		re1.layer_id = border_layer_id AND 
		re1.element_type = 2 AND
		ued1.edge_id = re1.element_id
	) AND
	b.id = re2.topogeo_id AND
	re2.layer_id = border_layer_id AND 
	re2.element_type = 2 AND
	c.edge_id = re2.element_id;
		

	RAISE NOTICE 'Step::::::::::::::::: 7';

	-- Clear the topology elements objects that does not have edges left
	PERFORM topology.clearTopoGeom(a.linje) 
	FROM topo_rein.reindrift_anlegg_linje  a,
	ttt2_objects_to_be_delted b
	WHERE a.id = b.id;
	
	RAISE NOTICE 'Step::::::::::::::::: 8';

	-- Delete those topology elements objects that does not have edges left
	DELETE FROM topo_rein.reindrift_anlegg_linje a
	USING ttt2_objects_to_be_delted b
	WHERE a.id = b.id;

	
	RAISE NOTICE 'Step::::::::::::::::: 94 af %, nc %',  (select count(*) from ttt2_affected_objects_id), (select count(*) from ttt2_not_covered_by_input_line);

	-- Find  lines that should be added again the because the objects which they belong to will be deleted
	command_string := topo_update.create_temp_tbl_def('ttt2_objects_to_be_updated','(id int, geom geometry)');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_objects_to_be_updated;
	INSERT INTO ttt2_objects_to_be_updated(id,geom)
	SELECT b.id, ST_union(ed.geom) AS geom
	FROM ttt2_affected_objects_id b,
	ttt2_not_covered_by_input_line ed,
	topo_rein_sysdata.relation re
	WHERE (b.linje).id = re.topogeo_id AND
	re.layer_id = border_layer_id AND 
	re.element_type = 2 AND  -- TODO use variable element_type_edge=2
	ed.edge_id != re.element_id
	GROUP BY b.id;

	RAISE NOTICE 'StepA::::::::::::::::: 1, rows %', (select count(*) from ttt2_objects_to_be_updated) ;

	-- Clear the old topology elements objects that should be updated
	PERFORM topology.clearTopoGeom(a.linje) 
	FROM topo_rein.reindrift_anlegg_linje  a,
	ttt2_objects_to_be_updated b
	WHERE a.id = b.id;
	
	
	RAISE NOTICE 'StepA::::::::::::::::: 2';

	-- Update the old topo objects with new values
	UPDATE topo_rein.reindrift_anlegg_linje AS a
	SET linje= topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance)
	FROM ttt2_objects_to_be_updated b
	WHERE a.id = b.id;


	-- We have now removed duplicate ref to any edges, this means that each edge is only used once
	--------------------- Stop: code to remove duplicate edges ---------------------
	--==============================================================================
	--==============================================================================


	RAISE NOTICE 'StepA::::::::::::::::: 3';

	
	-- Find topto that intersects with the new line drawn by the end user
	-- This lines should be returned, together with the topo object created
	command_string := topo_update.create_temp_tbl_as('ttt2_intersection_id','SELECT * FROM  topo_rein.reindrift_anlegg_linje limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_intersection_id;
	INSERT INTO ttt2_intersection_id
	SELECT distinct a.*  
	FROM 
	topo_rein.reindrift_anlegg_linje a, 
	ttt2_new_attributes_values a2,
	topo_rein_sysdata.relation re, 
	topology.layer tl,
	topo_rein_sysdata.edge_data  ed
	WHERE ST_intersects(ed.geom,a2.geom)
	AND topo_rein.get_relation_id(a.linje) = re.topogeo_id AND re.layer_id = tl.layer_id AND tl.schema_name = 'topo_rein' AND 
	tl.table_name = 'reindrift_anlegg_linje' AND ed.edge_id=re.element_id
	AND NOT EXISTS (SELECT 1 FROM ttt2_new_topo_rows_in_org_table nr where a.id = nr.id);

	RAISE NOTICE 'StepA::::::::::::::::: 4';

	
	-- create a empty table hold list og id's changed.
	-- TODO this should have moved to anothe place, but we need the result below
	command_string := topo_update.create_temp_tbl_as('ttt2_id_return_list','SELECT * FROM  ttt2_new_topo_rows_in_org_table limit 0');
	EXECUTE command_string;
	-- TRUNCATE TABLE ttt2_id_return_list;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_new_topo_rows_in_org_table a ;

	-- update the return table with intersected rows
	INSERT INTO ttt2_id_return_list(id)
	SELECT a.id FROM ttt2_intersection_id a ;
	
	RAISE NOTICE 'StepA::::::::::::::::: 5';


	IF num_edge_intersects < 3 THEN

		--------------------- Start: Find short eges to be removed  ---------------------
		-- Should be moved to a separate proc so we could reuse this code for other line 
		-- Find edges that are verry short and that are close to the edges that area drawn.
	
		
		-- Find the edges that intersects with the input line that are short and may be reomved
		command_string := topo_update.create_temp_tbl_def('ttt2_short_edge_list','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		INSERT INTO ttt2_short_edge_list(id,edge_id,geom)
		SELECT distinct a.id, ed.edge_id , ed.geom 
	    FROM 
		topo_rein_sysdata.relation re,
		ttt2_id_return_list ud, 
		topo_rein_sysdata.edge_data ed,
		topo_rein.reindrift_anlegg_linje  a,
		ttt2_new_topo_rows_in_org_table nr2,
		topo_rein_sysdata.relation re2,
		topo_rein_sysdata.edge_data ed2
		
		WHERE 
		ud.id = a.id AND
		(a.linje).id = re.topogeo_id AND
		re.layer_id = border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		
		-- replaces ST_Intersects(ed.geom,input_geom)
		-- ST_Intersects(nr2.linje,a.linje) and
	
		(nr2.linje).id = re2.topogeo_id and
		re2.layer_id = border_layer_id and 
		re2.element_type = 2 and  -- todo use variable element_type_edge=2
		ed2.edge_id = re2.element_id and
		(ed2.start_node = ed.start_node or
		ed2.end_node = ed.end_node or
		ed2.start_node = ed.end_node or
		ed2.start_node = ed.end_node) AND
	
		NOT EXISTS -- don't remove small line pices that are connected to another edges
		( 
			SELECT 1 FROM 
				topo_rein_sysdata.edge_data AS ed3,
				topo_rein_sysdata.edge_data AS ed4
			--	topo_rein_sysdata.edge_data ed
				WHERE 
--				ed2.edge_id != ed.edge_id AND -- This role is applied to it self
				(ed3.edge_id != ed.edge_id AND  
				(ed3.start_node = ed.start_node OR
				ed3.end_node = ed.start_node))
				AND
				(ed4.edge_id != ed.edge_id AND  
				(ed4.start_node = ed.end_node OR
				ed4.end_node = ed.end_node))
		) AND
		
		-- don't remove line that ara on line line and does
	--	NOT EXISTS 
	--	( 
	--		SELECT 1 FROM 
	--		topo_rein_sysdata.edge_data AS ed2
	--		WHERE 
	--		ed2.geom = ed.geom
	--	) 	AND
	
		EXISTS -- dont't remove small pices if this has the same length as single topoobject 
		( 
			SELECT 1 FROM 
			(
				SELECT ST_Length(ST_Union(eda.geom)) AS topo_length FROM 
				topo_rein_sysdata.relation re3,
				topo_rein_sysdata.relation re4,
				topo_rein_sysdata.edge_data eda
				WHERE 
				re3.layer_id = border_layer_id AND 
				re3.element_type = 2 AND  -- TODO use variable element_type_edge=2
				ed.edge_id = re3.element_id AND
				re4.topogeo_id = re3.topogeo_id AND
				re4.element_id = eda.edge_id
				GROUP BY eda.edge_id
			) AS r2
			WHERE ST_Length(ed.geom) < topo_length -- TODO adde test the relative length of the topo object
		) AND
		
		(
			-- for the lines drwan by the user we dont' need to check on min length 
			( 
				(a.linje).id = (nr2.linje).id AND
				ST_Length(ed.geom) < ST_Length(input_geo) AND
				ST_Length(input_geo)/ST_Length(ed.geom) > 9-- TODO find out what values to use here is this performance problem ?
			)
		OR
			(
				(a.linje).id != (nr2.linje).id AND
				ST_Length(ed.geom) < ST_Length(input_geo) AND
				ST_Length(input_geo)/ST_Length(ed.geom) > 9 AND -- TODO find out what values to use here is this performance problem ?
				ST_Length(ST_transform(ed.geom,32632)) < 500  -- TODO find out what values to use here is this performance problem ?
			)
		);
		
		
		
		RAISE NOTICE 'StepA::::::::::::::::: 6 sl %', (select count(*) from ttt2_short_edge_list);
	
		-- Create the new geo with out the short edges, this is what he objects should look like
		command_string := topo_update.create_temp_tbl_def('ttt2_no_short_object_list','(id int, geom geometry)');
		EXECUTE command_string;
		INSERT INTO ttt2_no_short_object_list(id,geom)
		SELECT b.id, ST_union(ed.geom) AS geom
		FROM ttt2_short_edge_list b,
		topo_rein_sysdata.edge_data ed,
		topo_rein_sysdata.relation re,
		topo_rein.reindrift_anlegg_linje  a
		WHERE a.id = b.id AND
		(a.linje).id = re.topogeo_id AND
		re.layer_id = border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT EXISTS (SELECT 1 FROM ttt2_short_edge_list WHERE ed.edge_id = edge_id)
		GROUP BY b.id;
	
		RAISE NOTICE 'StepA::::::::::::::::: 7';
	
	--	IF (SELECT ST_AsText(ST_StartPoint(geom)) FROM ttt2_new_attributes_values)::text = 'POINT(5.69699 58.55152)' THEN
	--		return;
	--	END IF;
	
		
		-- Clear the topology elements objects that should be updated
		PERFORM topology.clearTopoGeom(a.linje) 
		FROM topo_rein.reindrift_anlegg_linje  a,
		ttt2_no_short_object_list b
		WHERE a.id = b.id;
		
		-- Remove edges not used from the edge table
	 	command_string := FORMAT('
			SELECT ST_RemEdgeModFace(%1$L, ed.edge_id)
			FROM 
			ttt2_short_edge_list ued,
			%2$s ed
			WHERE 
			ed.edge_id = ued.edge_id 
			',
			border_topo_info.topology_name,
			border_topo_info.topology_name || '.edge_data'
		);
		
		RAISE NOTICE '%', command_string;
	
	    EXECUTE command_string;
	
	
		-- Update the topo objects with shared edges that stil hava 
		UPDATE topo_rein.reindrift_anlegg_linje AS a
		SET linje= topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance)
		FROM ttt2_no_short_object_list b
		WHERE a.id = b.id;
	
		
	
		--------------------- Stop: Find short eges to be removed  ---------------------
		--==============================================================================
		--==============================================================================
	
	
				
		-------------------- Start: split up edges when the input line intersects the line segment two times   ---------------------
		-- This makes is possible for the user remove the eges beetween two intersections
		-- Should be moved to a separate proc so we could reuse this code for other line 
		
		
		-- Test if there if both start and end point intersect with line a connected set of edges
		-- Connected means that they each edge is connnected
		
		-- find all edges covered by the input using ttt2_new_topo_rows_in_org_table a ;
		-- TODO this is already done above most times but in scases where the input line is not changed all we have to do it
		-- TDOO is this faster ? or should we just use to simple feature ???
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_list_for_input_line','(id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_list_for_input_line;
		INSERT INTO ttt2_final_edge_list_for_input_line
		SELECT distinct ud.id, ST_Union(ed.geom) AS geom
	    FROM 
		topo_rein_sysdata.relation re,
		ttt2_new_topo_rows_in_org_table ud, 
		topo_rein_sysdata.edge_data ed,
		topo_rein.reindrift_anlegg_linje a 
		WHERE 
		a.id = ud.id AND
		(a.linje).id = re.topogeo_id AND
		re.layer_id = layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id
		GROUP BY ud.id;
	
		-- find all edges intersected by input by but not input line it self by using ttt2_final_edge_list_for_intersect_line a ;
		-- TODO this is already done above most times but in scases where the input line is not changed all we have to do it
		-- TDOO is this faster ? or should we just use to simple feature ???
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_list_for_intersect_line','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_list_for_intersect_line;
		INSERT INTO ttt2_final_edge_list_for_intersect_line
		SELECT distinct ud.id, ed.edge_id, ed.geom AS geom
	    FROM 
		topo_rein_sysdata.relation re,
		ttt2_intersection_id ud, 
		topo_rein_sysdata.edge_data ed,
		topo_rein.reindrift_anlegg_linje a,
		ttt2_final_edge_list_for_input_line fl
		WHERE 
		a.id = ud.id AND
		(a.linje).id = re.topogeo_id AND
		re.layer_id = layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		ST_Intersects(fl.geom,ed.geom);
	
		
		-- find out eges in the touching objects that does not intesect withinput line and that also needs to be recreated
		command_string := topo_update.create_temp_tbl_def('ttt2_final_edge_left_list_intersect_line','(id int, edge_id int, geom geometry)');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_final_edge_left_list_intersect_line;
		INSERT INTO ttt2_final_edge_left_list_intersect_line
		SELECT distinct ud.id, ed.edge_id, ed.geom AS geom
	    FROM 
		topo_rein_sysdata.relation re,
		ttt2_intersection_id ud, 
		topo_rein_sysdata.edge_data ed,
		topo_rein.reindrift_anlegg_linje a
		WHERE 
		a.id = ud.id AND
		(a.linje).id = re.topogeo_id AND
		re.layer_id = border_layer_id AND 
		re.element_type = 2 AND  -- TODO use variable element_type_edge=2
		ed.edge_id = re.element_id AND
		NOT EXISTS (SELECT 1 FROM ttt2_final_edge_list_for_intersect_line WHERE ed.edge_id = edge_id);
	
		
	
	-- we are only interested in intersections with two or more edges are involved
	-- so remove this id with less than 2  
	-- Having this as rule is causeing other problems like it's difficult to recreate the problem.
	--	DELETE FROM ttt2_final_edge_list_for_intersect_line a
	--	USING 
	--	( 
	--		SELECT g.id FROM
	--		(SELECT e.id, count(*) AS num FROM  ttt2_final_edge_list_for_intersect_line AS e GROUP BY e.id) AS g
	--		WHERE num < 3
	--	) AS b
	--	WHERE a.id = b.id;
	
	
		-- for ecah of this edges create new separate topo objects so they are selectable for the user
		-- Update the topo objects with shared edges that stil hava 
		command_string := topo_update.create_temp_tbl_as('ttt2_new_intersected_split_objects','SELECT * FROM  topo_rein.reindrift_anlegg_linje limit 0');
		EXECUTE command_string;
		-- TRUNCATE TABLE ttt2_new_intersected_split_objects;
		WITH inserted AS (
			INSERT INTO topo_rein.reindrift_anlegg_linje(linje, felles_egenskaper, reindriftsanleggstype,reinbeitebruker_id)
			SELECT  
				topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance) AS linje,
				a.felles_egenskaper,
				a.reindriftsanleggstype,
				a.reinbeitebruker_id
			FROM 
			ttt2_final_edge_list_for_intersect_line b,
			topo_rein.reindrift_anlegg_linje a
			WHERE a.id = b.id
			RETURNING *
		)
		INSERT INTO ttt2_new_intersected_split_objects
		SELECT * FROM inserted;
	
	
		-- We have now added new topo objects for egdes that intersetcs no we need to modify the orignal topoobjects so we don't get any duplicates
	
		-- Clear the topology elements objects that should be updated
		PERFORM topology.clearTopoGeom( c.linje) 
		FROM 
		( 
			SELECT distinct a.linje
			FROM topo_rein.reindrift_anlegg_linje  a,
			ttt2_final_edge_list_for_intersect_line b
			WHERE a.id = b.id
		) AS c;
	
	
		-- Update the topo objects with shared edges that stil hava 
		UPDATE topo_rein.reindrift_anlegg_linje AS a
		SET linje= topology.toTopoGeom(b.geom, border_topo_info.topology_name, border_layer_id, border_topo_info.snap_tolerance)
		FROM ( 
			SELECT g.id, ST_Union(g.geom) as geom
			FROM ttt2_final_edge_left_list_intersect_line g
			GROUP BY g.id
		) AS b
		WHERE a.id = b.id;
	
	
		
		-- Delete those with now egdes left both in return list
		WITH deleted AS (
			DELETE FROM topo_rein.reindrift_anlegg_linje a
			USING 
			ttt2_final_edge_list_for_intersect_line b
			WHERE a.id = b.id AND
			NOT EXISTS (SELECT 1 FROM ttt2_final_edge_left_list_intersect_line c WHERE b.id = c.id)
			RETURNING a.id
		)
		DELETE FROM 
		ttt2_id_return_list a
		USING deleted
		WHERE a.id = deleted.id;

		
		-- update return list
		INSERT INTO ttt2_id_return_list(id)
		SELECT a.id FROM ttt2_new_intersected_split_objects a 
		WHERE NOT EXISTS (SELECT 1 FROM ttt2_final_edge_left_list_intersect_line c WHERE a.id = c.id);

	END IF;
	
	
	
	
	--------------------- Stop: split up edges when the input line intersects the line segment two times  ---------------------
	--==============================================================================
	--==============================================================================


	
	-- TODO should we also return lines that are close to or intersects and split them so it's possible to ??? 
	command_string := ' SELECT distinct tg.id AS id FROM ttt2_id_return_list tg';
	-- command_string := 'SELECT tg.id AS id FROM ' || border_topo_info.layer_schema_name || '.' || border_topo_info.layer_table_name || ' tg, new_rows_added_in_org_table new WHERE new.linje::geometry && tg.linje::geometry';
	RAISE NOTICE '%', command_string;
    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;
--}

--{ kept for backward compatility
CREATE OR REPLACE FUNCTION topo_update.create_line_edge_domain_obj(json_feature text) 
RETURNS TABLE(id integer) AS $$
  SELECT topo_update.create_line_edge_domain_obj($1, 'topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10);
$$ LANGUAGE 'sql';
--}


-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[23.6848135256,70.2941567505],[23.6861561246,70.2937237249],[23.6888489507,70.2928551851],[23.6896495555,70.2925466063],[23.6917889589,70.292156264],[23.6945956663,70.2918661088],[23.6965659512,70.2915742147],[23.6997477211,70.2913270875],[23.7033391524,70.2915039485],[23.7044653963,70.2916332891],[23.7071834727,70.2915684568],[23.7076455811,70.2914565778],[23.7081927635,70.2912602126],[23.7079468414,70.2907122103]]},"properties":{"reinbeitebruker_id":"YD","reindriftsanleggstype":1}}');

-- select topo_update.create_line_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[582408.943892817,7635222.4433961185],[621500.8918835252,7615523.766478926],[622417.1094145575,7630641.355740958]],"crs":{"type":"name","properties":{"name":"EPSG:32633"}}},"properties":{"Fellesegenskaper.Opphav":"Y","anleggstype":"12","reinbeitebruker_id ":"ZS","Fellesegenskaper.Kvalitet.Maalemetode":82}}');

