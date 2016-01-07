-- This is a function that is used to build surface based on the border objects that alreday exits
-- topoelementarray_data is reffrerance to the egdes in this layer

DROP FUNCTION IF EXISTS topo_update.build_surface_domain_obj(
json_feature text,
topoelementarray_data topoelementarray, 
  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  snap_tolerance float8) cascade;


CREATE OR REPLACE FUNCTION topo_update.build_surface_domain_obj(
json_feature text,
topoelementarray_data topoelementarray, 
  layer_schema text, 
  surface_layer_table text, surface_layer_column text,
  snap_tolerance float8) 
RETURNS TABLE(id integer) AS $$
DECLARE

json_result text;

surface_topo_info topo_update.input_meta_info ;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- used for logging
num_rows_affected int;

-- the number times the inlut line intersects
num_edge_intersects int;

-- holds the value for felles egenskaper from input
simple_sosi_felles_egenskaper_flate topo_rein.simple_sosi_felles_egenskaper;
felles_egenskaper_flate topo_rein.sosi_felles_egenskaper;

surface_topogeometry topogeometry;

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the target table
update_fields text[];

-- array of quoted field identifiers
-- for attribute fields passed in by user and known (by name)
-- in the temp table
update_fields_t text[];


BEGIN
	
	-- get meta data the surface 
	surface_topo_info := topo_update.make_input_meta_info(layer_schema, surface_layer_table , surface_layer_column );
	
	CREATE TEMP TABLE IF NOT EXISTS ttt2_new_attributes_values(properties json, felles_egenskaper topo_rein.sosi_felles_egenskaper);
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
		SELECT * INTO simple_sosi_felles_egenskaper_flate 
		FROM json_populate_record(NULL::topo_rein.simple_sosi_felles_egenskaper,
		(select properties from ttt2_new_attributes_values) );

	END IF;

	
	-- Create a temp table tha will hodl the row will be inserted at the end
	command_string := topo_update.create_temp_tbl_as(
	  'ttt2_new_topo_rows_in_org_table',
	  format('SELECT * FROM %I.%I LIMIT 0',
	  surface_topo_info.layer_schema_name,
	         surface_topo_info.layer_table_name));
	EXECUTE command_string;

	 -- insert one row to be able create update field
	insert into ttt2_new_topo_rows_in_org_table(id) values(1); 
	
-- Extract name of fields with not-null values:
  -- Extract name of fields with not-null values and append the table prefix n.:
  -- Only update json value that exits 
  SELECT
  	array_agg(quote_ident(update_column)) AS update_fields,
  	array_agg('n.'||quote_ident(update_column)) as update_fields_t
  INTO
  	update_fields,
  	update_fields_t
  FROM (
   SELECT distinct(key) AS update_column
   FROM ttt2_new_topo_rows_in_org_table t, json_each_text(to_json((t)))  ,
   (SELECT json_object_keys(t2.properties) as res FROM ttt2_new_attributes_values t2 ) as key_list
   WHERE key != 'id' AND 
   key = key_list.res 
  ) AS keys;

    
  RAISE NOTICE 'Extract name of not-null fields: %', update_fields_t;
  RAISE NOTICE 'Extract name of not-null fields: %', update_fields;

  -- we have got the update filds so we don'n need this row any more
  truncate ttt2_new_topo_rows_in_org_table;
  
	-- get the felles egeskaper flate object
	felles_egenskaper_flate := topo_rein.get_rein_felles_egenskaper_flate(simple_sosi_felles_egenskaper_flate);

	-- create the topo object 
	surface_topogeometry := topology.CreateTopoGeom( surface_topo_info.topology_name,surface_topo_info.element_type,surface_topo_info.border_layer_id,topoelementarray_data); 

  	-- Insert all matching column names into temp table ttt2_new_topo_rows_in_org_table 
  	command_string := format('INSERT INTO ttt2_new_topo_rows_in_org_table(%s,felles_egenskaper,%s)
		SELECT 
		%s,
		$1 as felles_egenskaper,
		$2 AS %s
		FROM ttt2_new_attributes_values t2,
         json_populate_record(
            null::ttt2_new_topo_rows_in_org_table,
            t2.properties) r',
    array_to_string(update_fields, ','),
    surface_topo_info.layer_feature_column,
    array_to_string(update_fields, ','),
	surface_topo_info.layer_feature_column);

	RAISE NOTICE 'command_string %' , command_string;

	EXECUTE command_string USING felles_egenskaper_flate, surface_topogeometry;
	
	-- Insert the rows in to master table 

	command_string := format('
	WITH inserted AS ( 
	INSERT INTO %I.%I(%s,felles_egenskaper,%s)
	SELECT %s,felles_egenskaper,%s FROM ttt2_new_topo_rows_in_org_table RETURNING * ), 
	deleted AS ( DELETE FROM ttt2_new_topo_rows_in_org_table ) 
	INSERT INTO ttt2_new_topo_rows_in_org_table SELECT * FROM inserted ',
	surface_topo_info.layer_schema_name,
	surface_topo_info.layer_table_name,
    array_to_string(update_fields, ','),
    surface_topo_info.layer_feature_column,
    array_to_string(update_fields, ','),
	surface_topo_info.layer_feature_column);

	RAISE NOTICE 'command_string %' , command_string;

	EXECUTE command_string USING felles_egenskaper_flate, surface_topogeometry;


	command_string := 'SELECT t.id FROM ttt2_new_topo_rows_in_org_table t';

    RETURN QUERY EXECUTE command_string;
    
END;
$$ LANGUAGE plpgsql;


--SELECT topo_update.create_line_edge_domain_obj(json,'topo_rein', 'arstidsbeite_var_grense', 'grense', 1e-10)
--FROM org_rein_sosi_dump.arstidsbeite_json_grense_v g ,org_rein_sosi_dump.rein_sosi_dump_arstidsbeite_var_flate f
--WHERE f.objectid = 5358 AND g.geo && f.geo and ST_intersects(f.geo,g.geo)


--SELECT topo_update.build_surface_domain_obj(r2.json,r1.topoelementarray,'topo_rein', 'arstidsbeite_var_flate', 'omrade', 1e-10) FROM
--(
--	select distinct ST_GetFaceGeometry('topo_rein_sysdata',l.face_id) as geo,
--		topology.TopoElementArray_Agg(ARRAY[l.face_id,3]) as topoelementarray, 
--		ST_union(l.mbr) as union_face
--	from 
--	topo_rein_sysdata.face as l
--	 WHERE l.mbr is not null
--	 group by l.face_id
--	 limit 1
--) AS r1,
--org_rein_sosi_dump.arstidsbeite_var_json_flate_v r2
--WHERE r2.geo && r1.geo
--AND ST_Covers(r2.geo,ST_PointOnSurface(r1.geo));

-- SELECT * from topo_rein.arstidsbeite_var_flate;

