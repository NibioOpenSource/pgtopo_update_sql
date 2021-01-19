-- Return a topojson document with the contents of the query results
-- topojson specs:
-- https://github.com/mbostock/topojson-specification/blob/master/README.md
--
-- NOTE: will use TopoGeometry identifier as the feature identifier
--
--{
CREATE OR REPLACE FUNCTION topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int, simplify_patteren int)
RETURNS text AS
$$
DECLARE
  tmptext text;
BEGIN
  return topo_update.query_to_topojson(query, srid_out, maxdecimaldigits, simplify_patteren,null);
END;
$$ LANGUAGE 'plpgsql' VOLATILE;

--\timing
--select length(topo_rein.query_to_topojson('select distinct a.* from topo_rein.arstidsbeite_var_topojson_flate_v a',32633,0,0));
