-- Return the geom from Json and transform it to correct zone

CREATE OR REPLACE FUNCTION topo_rein.get_geom_from_json(feat json, srid_out int) 
RETURNS geometry AS $$DECLARE

DECLARE 
geom geometry;
srid int;
BEGIN

	geom := ST_GeomFromGeoJSON(feat->>'geometry');
	srid = St_Srid(geom);
	
	IF (srid_out != srid) THEN
		geom := ST_transform(geom,srid_out);
	END IF;
	
	geom := ST_SetSrid(geom,srid_out);

	RAISE NOTICE 'srid %, geom  %',   srid_out, ST_AsEWKT(geom);

	RETURN geom;

END;
$$ LANGUAGE plpgsql IMMUTABLE;


