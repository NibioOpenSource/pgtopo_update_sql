-- Drop alle functions

DROP FUNCTION IF EXISTS topo_update.handle_input_json_props(client_json_feature json,  server_json_feature json, srid_out int)  cascade;

DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper(felles topo_rein.simple_sosi_felles_egenskaper ) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_flate(felles topo_rein.simple_sosi_felles_egenskaper ) cascade;


DROP FUNCTION IF EXISTS topo_rein.findExtent(schema_name text, table_name text , geocolumn_name text ) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_linje(localid_in int) cascade; 
DROP FUNCTION IF EXISTS topo_rein.get_rein_felles_egenskaper_flate(localid_in int) cascade; 
DROP FUNCTION IF EXISTS topo_update.get_linestring_no_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.get_topo_layer_id(topo_info topo_update.input_meta_info) cascade; 
DROP FUNCTION IF EXISTS topo_update.has_linestring_loose_ends(topo_info topo_update.input_meta_info, topo topogeometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.touches(_new_topo_objects regclass,id_to_check int)  cascade; 
DROP FUNCTION IF EXISTS topo_update.make_input_meta_info(layer_schema text, layer_table text, layer_column text, snap_tolerance float8)   cascade;

DROP FUNCTION IF EXISTS topo_rein.query_to_topojson(query text, srid_out int, maxdecimaldigits int, simplify_patteren int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(env box2d, srid_out int, maxdecimaldigits int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(srid_out int, maxdecimaldigits int) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_var_flate_topojson(_new_topo_objects regclass, srid_out int, maxdecimaldigits int) cascade;

DROP FUNCTION IF EXISTS topo_update.create_edge_surfaces(new_border_data topogeometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_edge_surfaces(new_border_data topogeometry, valid_user_geometry geometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_edge_surfaces(new_border_data topogeometry, valid_user_geometry geometry, felles_egenskaper_v topo_rein.sosi_felles_egenskaper)  cascade; 


DROP FUNCTION IF EXISTS topo_update.create_surface_edge(geo_in geometry) cascade; 
DROP FUNCTION IF EXISTS topo_update.update_domain_surface_layer(_new_topo_objects regclass) cascade; 
DROP FUNCTION IF EXISTS topo_update.update_domain_surface_layer(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info, _new_topo_objects regclass) cascade; 
DROP FUNCTION IF EXISTS topo_update.update_domain_surface_layer(surface_topo_info topo_update.input_meta_info, border_topo_info topo_update.input_meta_info, valid_user_geometry geometry,  _new_topo_objects regclass) cascade; 

DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(client_json_feature text,layer_schema text, surface_layer_table text, surface_layer_column text, border_layer_table text, border_layer_column text,snap_tolerance float8) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(client_json_feature text,layer_schema text, surface_layer_table text, surface_layer_column text, border_layer_table text, border_layer_column text,snap_tolerance float8,server_json_feature text) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(geo_in geometry,srid_out int, maxdecimaldigits int) cascade; 
DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(geo_in geometry) cascade;
DROP FUNCTION IF EXISTS topo_update.create_surface_edge_domain_obj(json_feature text)  cascade;

DROP FUNCTION IF EXISTS topo_update.create_line_edge_domain_obj(geo_in geometry) cascade;
DROP FUNCTION IF EXISTS topo_update.create_line_edge_domain_obj(geo_in geometry, json_feature text) cascade;
DROP FUNCTION IF EXISTS topo_update.create_line_edge_domain_obj(json_feature text) cascade;
DROP FUNCTION IF EXISTS topo_update.create_line_edge_domain_obj(json_feature text,layer_schema text, layer_table text, layer_column text,snap_tolerance float8) cascade;
DROP FUNCTION IF EXISTS topo_update.create_nocutline_edge_domain_obj(text,text,text,text,double precision,text) cascade;

DROP FUNCTION IF EXISTS topo_update.create_point_point_domain_obj(geo_in geometry) cascade;
DROP FUNCTION IF EXISTS topo_update.create_point_point_domain_obj(json_feature text) cascade;
DROP FUNCTION IF EXISTS topo_update.create_point_point_domain_obj(client_json_feature text,layer_schema text, layer_table text, layer_column text, snap_tolerance float8,server_json_feature text) cascade;


 

DROP FUNCTION IF EXISTS topo_update.apply_attr_on_topo_surface(json_feature text) cascade; 
DROP FUNCTION IF EXISTS topo_update.apply_line_on_topo_surface(geo_in geometry,  srid_out int, maxdecimaldigits int) cascade; 
DROP FUNCTION IF EXISTS topo_update.apply_attr_on_topo_line(json_feature text) cascade; 
DROP FUNCTION IF EXISTS topo_update.apply_attr_on_topo_point(json_feature text) cascade; 
 
DROP FUNCTION IF EXISTS topo_update.delete_topo_surface(geo_in geometry)  cascade; 
DROP FUNCTION IF EXISTS topo_update.delete_topo_surface(id_in int)  cascade; 
DROP FUNCTION IF EXISTS topo_update.delete_topo_line(id_in int)  cascade; 
DROP FUNCTION IF EXISTS topo_update.delete_topo_point(id_in int)  cascade; 

DROP FUNCTION IF EXISTS topo_rein.get_geom_from_json(feat json, srid_out int) cascade;

DROP FUNCTION IF EXISTS topo_rein.get_edges_within_toposurface(topogeometry) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_edges_within_faces(faces int[]) cascade;
DROP FUNCTION IF EXISTS topo_rein.get_edges_within_faces(faces int[], layer_id_in int ) cascade;
