-- Create new new surface object after new valid intersect line is drawn

-- TODO make general


CREATE OR REPLACE FUNCTION topo_update.create_edge_surfaces(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info , new_border_data topogeometry, valid_user_geometry geometry, felles_egenskaper_flate topo_rein.sosi_felles_egenskaper)
RETURNS SETOF topo_update.topogeometry_def AS $$
DECLARE

-- this border layer id will picked up by input parameters
border_layer_id int;

-- this surface layer id will picked up by input parameters
surface_layer_id int;

-- hold striped gei
edge_with_out_loose_ends geometry = null;

-- holds dynamic sql to be able to use the same code for different
command_string text;

-- holds the num rows affected when needed
num_rows_affected int;

-- number of rows to delete from org table
num_rows_to_delete int;

-- used for logging
add_debug_tables int = 0;

-- used for looping
rec RECORD;

-- used for creating new topo objects
new_surface_topo topology.topogeometry;

-- the closed geom if the instring is closed
valid_closed_user_geometry geometry;

BEGIN

	-- find border layer id
	border_layer_id := border_topo_info.border_layer_id;
	RAISE NOTICE 'border_layer_id   %',  border_layer_id ;

	-- find surface layer id
	surface_layer_id := surface_topo_info.border_layer_id;
	RAISE NOTICE 'surface_layer_id   %',  surface_layer_id ;

	RAISE NOTICE 'The topo objected added  %, isClosed %',  new_border_data, St_IsClosed(valid_user_geometry);

	IF St_IsClosed(valid_user_geometry) THEN
		valid_closed_user_geometry = ST_MakePolygon(valid_user_geometry);
	END IF;



	-------------------- Surface ---------------------------------

	-- find new facec that needs to be creted
	DROP TABLE IF EXISTS new_faces;
	CREATE TEMP TABLE new_faces(face_id int);

	-- find left faces
	command_string := FORMAT('INSERT INTO new_faces(face_id)
	SELECT DISTINCT(fa.face_id) as face_id
	FROM
	%I.relation re,
	%I.edge_data ed,
	%I.face fa
	WHERE
	%L = re.topogeo_id AND
    re.layer_id =  %L AND
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.left_face AND -- How do I know if a should use left or right ??
    fa.mbr IS NOT NULL',
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    new_border_data.id,
    border_layer_id);

	-- display the string
    -- RAISE NOTICE '%', command_string;
	-- execute the string
    EXECUTE command_string;


    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'Number of face objects found on the left side  % ',  num_rows_affected;

    -- find right faces
	command_string := FORMAT('INSERT INTO new_faces(face_id)
	SELECT DISTINCT(fa.face_id) as face_id
	FROM
	%I.relation re,
	%I.edge_data ed,
	%I.face fa
	WHERE
	%L = re.topogeo_id AND
    re.layer_id =  %L AND
    re.element_type = 2 AND  -- TODO use variable element_type_edge=2
    ed.edge_id = re.element_id AND
    fa.face_id=ed.right_face AND -- How do I know if a should use left or right ??
    fa.mbr IS NOT NULL',
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    border_topo_info.topology_name,
    new_border_data.id,
    border_layer_id);

	-- display the string
    -- RAISE NOTICE '%', command_string;
	-- execute the string
    EXECUTE command_string;



    GET DIAGNOSTICS num_rows_affected = ROW_COUNT;
	RAISE NOTICE 'topo_update.create_edge_surfaces, Number of face objects found on the right side  % ',  num_rows_affected;

	DROP TABLE IF EXISTS new_surface_data;
	-- Create a temp table to hold new surface data
	CREATE TEMP TABLE new_surface_data(surface_topo topogeometry);
	-- create surface geometry if a surface exits for the left side

	-- if input is a closed ring only geneate objects for faces


	FOR rec IN SELECT distinct face_id FROM new_faces
	LOOP
		--IF  NOT EXISTS(SELECT 1 FROM used_topo_faces WHERE face_id = rec.face_id) AND
		--EXISTS(SELECT 1 FROM valid_topo_faces WHERE face_id = rec.face_id) THEN
		-- Test if this surface already used by another topo object
			new_surface_topo := topology.CreateTopoGeom(surface_topo_info.topology_name,surface_topo_info.element_type,surface_layer_id,topology.TopoElementArray_Agg(ARRAY[rec.face_id,3])  );
			-- if not null
			IF new_surface_topo IS NOT NULL THEN

				-- check if this topo already exist
				-- TODO find out this chck is needed then we can only check on id
	--			IF NOT EXISTS(SELECT 1 FROM topo_rein.arstidsbeite_var_flate WHERE (omrade).id = (new_surface_topo).id) AND
	--			   NOT EXISTS(SELECT 1 FROM new_surface_data WHERE (surface_topo).id = (new_surface_topo).id)
	--			THEN
				-- Could we here have used topplogical equality
				IF valid_closed_user_geometry IS NOT NULL AND NOT ST_Intersects(valid_closed_user_geometry,ST_PointOnSurface (new_surface_topo::geometry)) THEN
					RAISE NOTICE 'topo_update.create_edge_surfaces, Use new topo object % , but this new surface is outside user input %',  ST_asText(valid_closed_user_geometry), ST_AsText(ST_PointOnSurface (new_surface_topo::geometry));
				ELSE
					RAISE NOTICE 'topo_update.create_edge_surfaces, Use new topo object % for face % created from user input %',  new_surface_topo, rec.face_id, new_border_data;
				END IF;

				INSERT INTO new_surface_data(surface_topo) VALUES(new_surface_topo);

			END IF;
		--END IF;
    END LOOP;


	-- We now objects that are missing attribute values that should be inheretaded from mother object.


	RETURN QUERY SELECT a.surface_topo::topogeometry as t FROM new_surface_data a;

END;
$$ LANGUAGE plpgsql;



-- SELECT * FROM topo_update.create_edge_surfaces((select topo_update.create_surface_edge('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.55375, 5.70152 58.55373, 5.70182 58.55131)'))::topogeometry)

