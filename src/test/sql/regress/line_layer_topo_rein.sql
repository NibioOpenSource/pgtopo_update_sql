SELECT '1', topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10);
SELECT '2', topo_update.delete_topo_line(1);
SELECT '3', topo_update.delete_topo_line(1);