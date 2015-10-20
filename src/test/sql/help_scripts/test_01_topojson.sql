SELECT  length(topo_rein.query_to_topojson('select * from topo_rein.arstidsbeite_var_grense', 32632, 0))::text;


select reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a WHERE a.omrade::geometry &&   (\x010300000001000000050000004280810eca0525400c2ba72efe4d413f3980810eca052540104548712d4e413fd8a9420fca052540ef934a712d4e413fe1a9420fca052540eb79a92efe4d413f4280810eca0525400c2ba72efe4d413f)::geometry)

SELECT  topo_rein.query_to_topojson('select * from topo_rein.reindrift_anlegg_linje', 32632, 0);



SELECT  topo_rein.query_to_topojson('select * from topo_rein.arstidsbeite_var_flate', 32632, 0);

SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id,omrade from topo_rein.arstidsbeite_var_flate', 32632, 0);


SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id, reindrift_sesongomrade_kode, omrade from topo_rein.arstidsbeite_var_flate', 4258, 7);

SELECT  topo_rein.query_to_topojson('select surface_topo from topo_rein.new_surface_data_for_edge', 4258,5);

select reinbeitebruker_id,omrade from topo_rein.arstidsbeite_var_flate

SELECT  topo_rein.query_to_topojson('select reinbeitebruker_id, reindrift_sesongomrade_kode, omrade from topo_rein.arstidsbeite_var_flate', 32632, 0);

select ST_AsBinary(ST_GeomFromEWKT('POLYGON ((10.511307195003727 0.0005280963062487, 10.511307195003711 0.0005281183135272, 10.511307217490796 0.0005281183135436, 10.511307217490812 0.0005280963062651, 10.511307195003727 0.0005280963062487))'))

select reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a WHERE a.omrade::geometry &&  ST_GeomFromEWKT('POLYGON ((10.511307195003727 0.0005280963062487, 10.511307195003711 0.0005281183135272, 10.511307217490796 0.0005281183135436, 10.511307217490812 0.0005280963062651, 10.511307195003727 0.0005280963062487))')

SELECT reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate WHERE id in (1,2)

select ST_AsText(ST_Union(ST_Intersection(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom))) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom);

select ST_Union(ST_Intersection(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom)) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom);

select ST_NumGeometries(ST_Union(ST_Intersection(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom))) FROM topo_rein_sysdata.edge_data e WHERE ST_Intersects(ST_GeomFromEWKT('SRID=4258;LINESTRING(19.3549069163725 69.8825496452282,19.4303545452396 69.8669515977129)'),e.geom);

select id, reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a WHERE a.omrade::geometry &&  ST_GeomFromEWKT('POLYGON ((16.97999564191308 68.43998066893752, 16.984891883715484 68.49584255933902, 17.283282372748236 68.4920466014126, 17.27765152643165 68.4361955000773, 16.97999564191308 68.43998066893752))') 


select id, reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a WHERE a.omrade::geometry &&  ST_GeomFromEWKT('POLYGON ((16.97999564191308 68.43998066893752, 16.984891883715484 68.49584255933902, 17.283282372748236 68.4920466014126, 17.27765152643165 68.4361955000773, 16.97999564191308 68.43998066893752))') 


db01utv postgres@sl=# select id 
from topo_rein.arstidsbeite_var_flate a ,topo_rein_sysdata.face fa, topo_rein_sysdata.relation re, topology.layer tl
WHERE fa.mbr && ST_GeomFromEWKT('POLYGON ((16.97999564191308 68.43998066893752, 16.984891883715484 68.49584255933902, 17.283282372748236 68.4920466014126, 17.27765152643165 68.4361955000773, 16.97999564191308 68.43998066893752))') AND
topo_rein.get_relation_id(a.omrade) = re.topogeo_id and re.layer_id = tl.layer_id and tl.schema_name = 'topo_rein' and tl.table_name = 'arstidsbeite_var_flate' and fa.face_id=re.element_id ; 
 id  
-----
 222
 223
 228
 229
 210
 211
(6 rows)

Time: 1.856 ms

db01utv postgres@sl=# select id 
from topo_rein.arstidsbeite_var_flate a 
WHERE a.omrade::geometry &&  ST_GeomFromEWKT('POLYGON ((16.97999564191308 68.43998066893752, 16.984891883715484 68.49584255933902, 17.283282372748236 68.4920466014126, 17.27765152643165 68.4361955000773, 16.97999564191308 68.43998066893752))') ;
 id  
-----
 222
 223
 210
 211
 229
 228
(6 rows)

Time: 251.583 ms
db01utv postgres@sl=# 



getTopoJson with length 276011, in 201 milli. secs. using select id, reinbeitebruker_id,reindrift_sesongomrade_kode,omrade from topo_rein.arstidsbeite_var_flate a,topo_rein_sysdata.face fa, topo_rein_sysdata.relation re, topology.layer tl WHERE fa.mbr && ST_GeomFromEWKT('POLYGON ((15.453222761463891 68.2518400245376, 15.471719965769845 69.14611185788299, 20.37691389397668 69.06249543521308, 20.16722849705953 68.1719678307436, 15.453222761463891 68.2518400245376))') AND topo_rein.get_relation_id(a.omrade) = re.topogeo_id and re.layer_id = tl.layer_id and tl.schema_name = 'topo_rein' and tl.table_name = 'arstidsbeite_var_flate' and fa.face_id=re.element_id - 


select count(id)
from topo_rein.arstidsbeite_var_flate a ,topo_rein_sysdata.face fa, topo_rein_sysdata.relation re, topology.layer tl
WHERE fa.mbr && ST_MakeEnvelope('-Infinity', '-Infinity', 'Infinity', 'Infinity') AND
topo_rein.get_relation_id(a.omrade) = re.topogeo_id and re.layer_id = tl.layer_id and tl.schema_name = 'topo_rein' and tl.table_name = 'arstidsbeite_var_flate' and fa.face_id=re.element_id ; 


selecy 