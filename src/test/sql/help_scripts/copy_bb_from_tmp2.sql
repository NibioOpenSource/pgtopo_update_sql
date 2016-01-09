
-- topo_rein.arstidsbeite_var_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'arstidsbeite_var_flate', 'omrade', 'org_rein_sosi_dump.arstidsbeite_var_json_flate_v', 
'arstidsbeite_var_grense','grense', 'org_rein_sosi_dump.arstidsbeite_var_json_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.arstidsbeite_sommer_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'arstidsbeite_sommer_flate', 'omrade', 'org_rein_sosi_dump.arstidsbeite_sommer_json_flate_v', 
'arstidsbeite_sommer_grense','grense', 'org_rein_sosi_dump.arstidsbeite_sommer_json_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.arstidsbeite_host_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'arstidsbeite_host_flate', 'omrade', 'org_rein_sosi_dump.arstidsbeite_host_json_flate_v', 
'arstidsbeite_host_grense','grense', 'org_rein_sosi_dump.arstidsbeite_host_json_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.arstidsbeite_hostvinter_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'arstidsbeite_hostvinter_flate', 'omrade', 'org_rein_sosi_dump.arstidsbeite_hostvinter_json_flate_v', 
'arstidsbeite_hostvinter_grense','grense', 'org_rein_sosi_dump.arstidsbeite_hostvinter_json_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.arstidsbeite_vinter_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'arstidsbeite_vinter_flate', 'omrade', 'org_rein_sosi_dump.arstidsbeite_vinter_json_flate_v', 
'arstidsbeite_vinter_grense','grense', 'org_rein_sosi_dump.arstidsbeite_vinter_json_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.beitehage_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'beitehage_flate', 'omrade', 'org_rein_sosi_dump.rein_sosi_dump_beitehage_flate_v', 
'beitehage_grense','grense', 'org_rein_sosi_dump.rein_sosi_dump_beitehage_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));


-- topo_rein.oppsamlingomr_flate
SELECT  org_rein_sosi_dump.simplefeature_2_topo_surface(
'topo_rein',
'oppsamlingomr_flate', 'omrade', 'org_rein_sosi_dump.rein_sosi_dump_oppsamlingomr_flate_v', 
'oppsamlingomr_grense','grense', 'org_rein_sosi_dump.rein_sosi_dump_oppsamlingomr_grense_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));



-- topo_rein.reindrift_anlegg_linje
SELECT  org_rein_sosi_dump.simplefeature_2_topo_line('topo_rein',
'reindrift_anlegg_linje', 'linje', 'org_rein_sosi_dump.drift_anlegg_json_linje_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));
 

-- topo_rein.rein_trekklei_linje
SELECT  org_rein_sosi_dump.simplefeature_2_topo_line('topo_rein',
'rein_trekklei_linje', 'linje', 'org_rein_sosi_dump.trekklei_json_linje_v', 1e-10,
 ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258));
 


-- topo_rein.reindrift_anlegg_punkt
SELECT topo_update.create_point_point_domain_obj(json, 'topo_rein',
'reindrift_anlegg_punkt', 'punkt', 1e-10) 
from org_rein_sosi_dump.drift_anlegg_json_punkt_v
WHERE geo && ST_GeomFromText('POLYGON((19.2694832914105 69.0764165120669,19.2694832914105 70.2309860481278,20.8513219423093 70.2309860481278,20.8513219423093 69.0764165120669,19.2694832914105 69.0764165120669))',4258);

