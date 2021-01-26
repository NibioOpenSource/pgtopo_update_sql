-- code picked from http://gis.stackexchange.com/questions/94049/how-to-get-the-data-type-of-each-column-from-a-postgis-table


-- find datatype for given table and column  
CREATE OR REPLACE FUNCTION topo_help_get_data_type(_t text, _c text)
  RETURNS text AS
$body$
DECLARE
    _schema text;
    _table text;
    data_type text;
BEGIN
-- Prepare names to use in index and trigger names
	IF _t::text LIKE '%.%' THEN
	    _schema := regexp_replace (split_part(_t::text, '.', 1),'"','','g');
	    _table := regexp_replace (split_part(_t::text, '.', 2),'"','','g');
    ELSE
        _schema := 'public';
        _table := regexp_replace(_t::text,'"','','g');
    END IF;

    RAISE NOTICE '_schema %, _table % _c %', _schema, _table, _c;

	data_type := (SELECT format_type(a.atttypid, a.atttypmod)
	    FROM pg_attribute a 
	    JOIN pg_class b ON (a.attrelid = b.oid)
	    JOIN pg_namespace c ON (c.oid = b.relnamespace)
	WHERE
	    b.relname = _table AND
	    c.nspname = _schema AND
    	a.attname = _c);

    	
    RETURN data_type;
END
$body$ LANGUAGE plpgsql;

-- give all execute acess
GRANT EXECUTE ON FUNCTION topo_help_get_data_type(_t text, _c text) TO public;

--SELECT topo_help_get_data_type('org_rein_sosi_dump.rein_konsesjonomr_flate','geom');

-- select topo_help_get_data_type('sl_esh.enrute_res_ar5_markslag_resultat','geo');

-- reuturn POINT, LINE, POLYGON, COLLECTION or null if gem column
-- return the correct feature type based simple feuature gemeometry type 
CREATE OR REPLACE FUNCTION topo_help_get_feature_type(type_def text)
  RETURNS text AS
$body$
DECLARE
    geo_type text = null;
BEGIN
-- Prepare names to use in index and trigger names
	IF type_def::text ILIKE 'geometry%Polygon%' THEN
		geo_type := 'POLYGON';
	ELSIF type_def::text ILIKE 'geometry%Line%' THEN
		geo_type := 'LINE';
	ELSIF type_def::text ILIKE 'geometry%Point%' THEN
		geo_type := 'POINT';
	ELSIF type_def::text ILIKE 'geometry' THEN
		-- we asume it's a suface but this is just a 
		geo_type := 'POLYGON';
    END IF;

    RETURN geo_type;
END
$body$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION  topo_help_get_feature_type(type_def text) TO public;

--select topo_help_get_feature_type(topo_help_get_data_type('sl_esh.enrute_res_ar5_markslag_resultat','geo'));
--select topo_help_get_feature_type('geometry(Point)');


-- reuturn POINT, LINE, POLYGON, COLLECTION or null if gem column
-- concert Point, line
CREATE OR REPLACE FUNCTION topo_help_get_sf_multi_feature_type(type_def text)
  RETURNS text AS
$body$
DECLARE
    geo_type text = null;
BEGIN
-- Prepare names to use in index and trigger names
	IF type_def::text ILIKE 'POLYGON' THEN
		geo_type := 'MultiPolygon';
	ELSIF type_def::text ILIKE 'LINE' THEN
		geo_type := 'MultiLineString';
	ELSIF type_def::text ILIKE 'POINT' THEN
		geo_type := 'MultiPoint';
	ELSIF type_def::text ILIKE 'geometry' THEN
		-- we asume it's a suface but this is just a 
		geo_type := 'Handles only  POINT, LINE, POLYGON in function topo_help_get_sf_multi_feature_type';
    ELSE
		RAISE NOTICE 'geo type not found for  %', text;
    END IF;

    RETURN geo_type;
END
$body$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION  topo_help_get_sf_multi_feature_type(type_def text) TO public;
