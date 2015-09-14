
-- Drop alle functions
DROP FUNCTION IF EXISTS topo_rein.findextent(text,text,text); 
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(env box2d,srid_out int, maxdecimaldigits int);
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_flate(localid_in int);
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_linje(localid_in int);
DROP FUNCTION IF EXISTS topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass); 
DROP FUNCTION IF EXISTS topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info);
DROP FUNCTION IF EXISTS topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, _tbl regclass);
DROP FUNCTION IF EXISTS topo_update.apply_line_on_topo_surface(geo_in geometry);
