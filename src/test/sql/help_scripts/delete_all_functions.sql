-- Drop alle functions
DROP FUNCTION IF EXISTS topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text ) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_linje(localid_in int) cascade; 
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_flate(localid_in int) cascade; 
DROP FUNCTION IF EXISTS topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) cascade; 
DROP FUNCTION IF EXISTS topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) cascade; 

DROP FUNCTION IF EXISTS topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(env box2d, srid_out int, maxdecimaldigits int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(srid_out int, maxdecimaldigits int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(_new_topo_objects regclass, srid_out int, maxdecimaldigits int) cascade;

DROP FUNCTION IF EXISTS topo_update.create_edge_surfaces(new_border_data topogeometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_surface_edge(geo_in geometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.update_domain_surface_layer(_new_topo_objects regclass) cascade; 

DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(geo_in geometry,srid_out int, maxdecimaldigits int) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(geo_in geometry) cascade;

DROP FUNCTION IF EXISTS topo_update.create_line_edge_domain_obj(geo_in geometry) cascade;

DROP FUNCTION IF EXISTS topo_update.apply_attr_on_topo_surface(json_feature text) cascade; 
DROP FUNCTION IF EXISTS topo_update.apply_line_on_topo_surface(geo_in geometry,  srid_out int, maxdecimaldigits int) cascade; 
 
DROP FUNCTION IF EXISTS topo_update.delete_topo_surface(geo_in geometry)  cascade; 
DROP FUNCTION IF EXISTS topo_update.delete_topo_surface(id_in int)  cascade; 