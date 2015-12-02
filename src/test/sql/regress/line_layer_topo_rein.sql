SELECT '1', topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10);
SELECT '2', reinbeitebruker_id , reindriftsanleggstype, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje;
SELECT '3', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reindriftsanleggstype":"5","reinbeitebruker_id":"ZA","fellesegenskaper.forstedatafangstdato":"2013-12-01","fellesegenskaper.verifiseringsdato":"2014-12-01","fellesegenskaper.oppdateringsdato":"2015-12-01","fellesegenskaper.opphav":"X"}}','topo_rein', 'reindrift_anlegg_linje', 'linje');
SELECT '4', reinbeitebruker_id , reindriftsanleggstype, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje;
SELECT '5', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reindriftsanleggstype":"4","reinbeitebruker_id":"ZA"}}','topo_rein', 'reindrift_anlegg_linje', 'linje');
SELECT '7', reinbeitebruker_id , reindriftsanleggstype, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje;
SELECT '8', topo_update.delete_topo_line(1,'topo_rein', 'reindrift_anlegg_linje', 'linje');
SELECT '9', reinbeitebruker_id , reindriftsanleggstype FROM topo_rein.reindrift_anlegg_linje;
SELECT '10', topo_update.delete_topo_line(1,'topo_rein', 'reindrift_anlegg_linje', 'linje');
SELECT '11', topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751]]}}','topo_rein', 'rein_trekklei_linje', 'linje', 1e-10);
SELECT '12', reinbeitebruker_id , (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.rein_trekklei_linje;
SELECT '13', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH"}}','topo_rein', 'rein_trekklei_linje', 'linje');
SELECT '14', reinbeitebruker_id , (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.rein_trekklei_linje;
SELECT '15', topo_update.delete_topo_line(1,'topo_rein', 'rein_trekklei_linje', 'linje');
SELECT '16', reinbeitebruker_id , (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.rein_trekklei_linje;
SELECT '17', topo_update.delete_topo_line(1,'topo_rein', 'rein_trekklei_linje', 'linje');

