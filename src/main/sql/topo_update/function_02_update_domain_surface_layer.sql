-- apply the list of new surfaces to the exting list
-- return the id's of the rows affected

-- DROP FUNCTION topo_update.update_domain_surface_layer(_new_topo_objects regclass) cascade;


CREATE OR REPLACE FUNCTION topo_update.update_domain_surface_layer(_new_topo_objects regclass) 
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

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

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- The border topology
new_border_data topogeometry;

-- used for logging
add_debug_tables int = 0;

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
	
	-- find border layer id
	border_layer_id := topo_update.get_topo_layer_id(border_topo_info);
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;
	
	-- find surface layer id
	surface_layer_id := topo_update.get_topo_layer_id(surface_topo_info);
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;

	-- get the data into a new tmp table
	DROP TABLE IF EXISTS new_surface_data; 

	
	EXECUTE format('CREATE TEMP TABLE new_surface_data AS (SELECT * FROM %s)', _new_topo_objects);
	ALTER TABLE new_surface_data ADD COLUMN id_foo SERIAL PRIMARY KEY;
	
	DROP TABLE IF EXISTS old_surface_data; 
	-- find out if any old topo objects overlaps with this new objects using the relation table
	-- by using the surface objects owned by the both the new objects and the exting one
	CREATE TEMP TABLE old_surface_data AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	topo_rein_sysdata.relation re_tmp,
	new_surface_data new_sd
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.element_id = re_tmp.element_id AND
	re_tmp.layer_id = surface_layer_id AND
	re_tmp.element_type = 3 AND
	(new_sd.surface_topo).id = re_tmp.topogeo_id AND
	(new_sd.surface_topo).id != re.topogeo_id);
	
	
	DROP TABLE IF EXISTS old_surface_data_not_in_new; 
	-- find any old objects that are not covered totaly by 
	-- this objets should not be deleted, but the geometry should only decrease in size.
	-- TODO add a test case for this
	CREATE TEMP TABLE old_surface_data_not_in_new AS 
	(SELECT 
	re.* 
	FROM 
	topo_rein_sysdata.relation re,
	old_surface_data re_tmp
	WHERE 
	re.layer_id = surface_layer_id AND
	re.element_type = 3 AND
	re.topogeo_id = re_tmp.topogeo_id AND
	re.element_id NOT IN (SELECT element_id FROM old_surface_data));
	
	
	DROP TABLE IF EXISTS old_rows_be_reused;
	-- IF old_surface_data_not_in_new is empty we know that all areas are coverbed by the new objects
	-- and we can delete/resuse this objects for the new rows
	-- Get a list of old row id's used
	CREATE TEMP TABLE old_rows_be_reused AS 
	-- we can have distinct here 
	(SELECT distinct(old_data_row.id) FROM 
	topo_rein.arstidsbeite_var_flate old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.omrade).id = sf.topogeo_id);  
	
	
	-- Take a copy of old attribute values because they will be needed when you add new rows.
	-- The new surfaces should pick up old values from the old row attributtes that overlaps the new rows
	-- We also take copy of the geometry we need that to overlaps when we pick up old values
	-- TODO this should have been solved by using topology relation table, but I do that later 
	DROP TABLE IF EXISTS old_rows_attributes;
	CREATE TEMP TABLE old_rows_attributes AS 
	(SELECT old_data_row.*, old_data_row.omrade::geometry as foo_geo FROM 
	topo_rein.arstidsbeite_var_flate old_data_row,
	old_surface_data sf 
	WHERE (old_data_row.omrade).id = sf.topogeo_id);  

		
	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list topo objects to be reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t1;
		CREATE TABLE topo_rein.update_domain_surface_layer_t1 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'reuse topo objcts' || r.omrade::text AS topo
			FROM topo_rein.arstidsbeite_var_flate r, old_rows_be_reused reuse WHERE reuse.id = r.id) ;
	END IF;

	
	-- We now know which rows we can reuse clear out old data rom the realation table
	UPDATE topo_rein.arstidsbeite_var_flate r
	SET omrade = clearTopoGeom(omrade)
	FROM old_rows_be_reused reuse
	WHERE reuse.id = r.id;
	
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number rows to be reused in org table %',  num_rows_affected;

	SELECT (num_rows_affected - (SELECT count(*) FROM new_surface_data)) INTO num_rows_to_delete;

	RAISE NOTICE 'Number rows to be added in org table  %',  count(*) FROM new_surface_data;

	RAISE NOTICE 'Number rows to be deleted in org table  %',  num_rows_to_delete;

	-- When overwrite we may have more rows in the org table so we may need do delete the rows not needed 
	-- from  topo_rein.arstidsbeite_var_flate, we the just delete the left overs 
	DELETE FROM topo_rein.arstidsbeite_var_flate
	WHERE ctid IN (
	SELECT r.ctid FROM
	topo_rein.arstidsbeite_var_flate r,
	old_rows_be_reused reuse
	WHERE reuse.id = r.id 
	LIMIT  greatest(num_rows_to_delete, 0));
	

	
	-- Also rows that could be reused, since I was not able to update those.
	DROP TABLE IF EXISTS new_rows_updated_in_org_table;
	CREATE TEMP TABLE new_rows_updated_in_org_table AS (SELECT * FROM topo_rein.arstidsbeite_var_flate limit 0);
	WITH updated AS (
		DELETE FROM topo_rein.arstidsbeite_var_flate old
		USING old_rows_be_reused reuse
		WHERE old.id = reuse.id
		returning *
	)
	INSERT INTO new_rows_updated_in_org_table(omrade)
	SELECT omrade FROM updated;
	GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number old rows to deleted table %',  num_rows_affected;


	-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list new objects added reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t2;
		CREATE TABLE topo_rein.update_domain_surface_layer_t2 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'old rows deleted update' || r.omrade::text AS topo
			FROM new_rows_updated_in_org_table r) ;
	END IF;

	-- insert missing rows and keep a copy in them a temp table
	DROP TABLE IF EXISTS new_rows_added_in_org_table;
	CREATE TEMP TABLE new_rows_added_in_org_table AS (SELECT * FROM topo_rein.arstidsbeite_var_flate limit 0);
	WITH inserted AS (
	INSERT INTO  topo_rein.arstidsbeite_var_flate(omrade,felles_egenskaper)
	SELECT new.surface_topo, new.felles_egenskaper_flate as felles_egenskaper
	FROM new_surface_data new
	WHERE NOT EXISTS ( SELECT f.id FROM topo_rein.arstidsbeite_var_flate f WHERE (new.surface_topo).id = (f.omrade).id )
	returning *
	)
	INSERT INTO new_rows_added_in_org_table(id,omrade)
	SELECT inserted.id, omrade FROM inserted;

		-- Only used for debug
	IF add_debug_tables = 1 THEN
		-- list new objects added reused
		-- get new objects created from topo_update.create_edge_surfaces
		DROP TABLE IF EXISTS topo_rein.update_domain_surface_layer_t3;
		CREATE TABLE topo_rein.update_domain_surface_layer_t3 AS 
		( SELECT r.id, r.omrade::geometry AS geo, 'new topo objcts' || r.omrade::text AS topo
			FROM new_rows_added_in_org_table r) ;
	END IF;


	-- update the newly inserted rows with attribute values based from old_rows_table
	UPDATE topo_rein.arstidsbeite_var_flate a
	SET 
	reinbeitebruker_id  = c.reinbeitebruker_id, 
	reindrift_sesongomrade_kode = c.reindrift_sesongomrade_kode,
	felles_egenskaper = c.felles_egenskaper
	FROM new_rows_added_in_org_table b, 
	old_rows_attributes c
	WHERE 
    a.id = b.id AND                           
    ST_Intersects(c.foo_geo,ST_pointOnSurface(a.omrade::geometry));
    -- ST_overlaps does not work

   	-- update the newly inserted rows with attribute values based from old_rows_table

    -- find the rows toubching
  	DROP TABLE IF EXISTS touching_surface;
	CREATE TEMP TABLE touching_surface AS (SELECT topo_update.touches('topo_rein.arstidsbeite_var_flate',a.id) as id FROM new_rows_added_in_org_table a);

	UPDATE topo_rein.arstidsbeite_var_flate a
	SET reinbeitebruker_id  = d.reinbeitebruker_id, 
	reindrift_sesongomrade_kode = d.reindrift_sesongomrade_kode,
	felles_egenskaper = d.felles_egenskaper
	FROM 
	topo_rein.arstidsbeite_var_flate d,
	touching_surface b
	WHERE 
	a.reinbeitebruker_id is null AND
	d.id = b.id ;
    
	
	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;

	
END;
$$ LANGUAGE plpgsql;



