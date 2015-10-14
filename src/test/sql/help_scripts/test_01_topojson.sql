SELECT  topo_rein.query_to_topojson('select * from topo_rein.arstidsbeite_var_grense', 32632, 0);

SELECT  topo_rein.query_to_topojson('select * from topo_rein.arstidsbeite_var_flate', 32632, 0);

SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id,omrade from topo_rein.arstidsbeite_var_flate', 32632, 0);


SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id, reindrift_sesongomrade_kode, omrade from topo_rein.arstidsbeite_var_flate', 4258, 7);

SELECT  topo_rein.query_to_topojson('select surface_topo from topo_rein.new_surface_data_for_edge', 4258,5);

select reinbeitebruker_id,omrade from topo_rein.arstidsbeite_var_flate

SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id, reindrift_sesongomrade_kode, omrade from topo_rein.arstidsbeite_var_flate', 32632, 0);

select reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a WHERE a.omrade::geometry &&  ST_GeomFromEWKT('POLYGON ((10.511307195003727 0.0005280963062487, 10.511307195003711 0.0005281183135272, 10.511307217490796 0.0005281183135436, 10.511307217490812 0.0005280963062651, 10.511307195003727 0.0005280963062487))')

SELECT reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate WHERE id in (1,2)