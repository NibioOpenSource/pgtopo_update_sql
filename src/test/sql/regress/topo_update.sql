SET pgtopo_update.session_id ='session_id';
SET pgtopo_update.draw_line_opr = '1';
SET client_min_messages to 'WARNING';

-- TODO  add set pgtopo_update.session_replication_role

-- Repeat all tests with the new function names.
--moved to anonther area because this behaves differrent og postgres 9.3 and 9.5, if it's a bug or not depends how it's defined the code to work.
--Is it valid to have lines in topology that is just by any domein object, may it should thats nice wai to keep the history
--SELECT '1', ST_length(topology.toTopoGeom('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.553751)', 'topoq_rein_sysdata_ran', (SELECT tl.layer_id FROM topology.layer tl WHERE tl.schema_name = 'topo_rein' AND tl.table_name = 'reindrift_anlegg_linje'), 0.0000000001));
--SELECT '2', ST_length(topology.toTopoGeom('SRID=4258;LINESTRING (5.70182 58.55131, 5.70368 58.55134, 5.70403 58.553751, 5.705207 58.552386)', 'topo_rein_sysdata_ran', (SELECT tl.layer_id FROM topology.layer tl WHERE tl.schema_name = 'topo_rein' AND tl.table_name = 'reindrift_anlegg_linje'), 0.0000000001)); 
SELECT '1', ROUND(ST_length(topology.toTopoGeom('SRID=4258;LINESTRING (5.70182 59.55131, 5.70368 59.55134, 5.70403 59.553751)', 'topo_rein_sysdata_ran', (SELECT tl.layer_id FROM topology.layer tl WHERE tl.schema_name = 'topo_rein' AND tl.table_name = 'reindrift_anlegg_linje'), 0.0000000001))::numeric,15);
SELECT '2', ST_length(topology.toTopoGeom('SRID=4258;LINESTRING (5.70182 59.55131, 5.70368 59.55134, 5.70403 59.553751, 5.705207 59.552386)', 'topo_rein_sysdata_ran', (SELECT tl.layer_id FROM topology.layer tl WHERE tl.schema_name = 'topo_rein' AND tl.table_name = 'reindrift_anlegg_linje'), 0.0000000001)); 

-- ======= Create surface object in layer arstidsbeite_var_flate  ======= --
--SET pgtopo_update.req_attribute_list='reindrift_sesongomrade_kode,reinbeitebruker_id'; --set of attributes need to reah a valid state

SELECT '3', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]},"properties":{"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.forstedatafangstdato":"2016-01-01","fellesegenskaper.verifiseringsdato":null,"Fellesegenskaper.Kvalitet.Maalemetode":82}}','topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense',  1e-10)) AS R;
SELECT '03_01', status, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate WHERE id = (select max(id) FROM topo_rein.arstidsbeite_var_flate) AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '03_02', (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_grense WHERE id = (select max(id) FROM topo_rein.arstidsbeite_var_grense) AND (felles_egenskaper).oppdateringsdato = current_date;
-- Check that update log has no values for arstidsbeite_var_flate
select '3_data_update_log', count(*) from topo_rein.data_update_log e where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate';
-- Check that new data_update_log_new_v has no values fro arstidsbeite_var_flate since no update has be done yet, there is zero rows here because the added row has not reached a valid state yet
select '3_data_update_log_new_v', count(*) from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and json_after is not null and json_after::text <> '{}'::text;

-- ======= Create line object in layer reindrift_anlegg_linje and update it,   ======= --
SELECT '4', count(id) FROM (SELECT 1 AS id FROM  topo_update.create_line_edge_domain_obj('{"type":"Feature","properties":{"fellesegenskaper.verifiseringsdato":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.opphav":"Reindriftsforvaltningen"},"geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '04_01', count(*) FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date AND (felles_egenskaper).forstedatafangstdato = current_date AND (felles_egenskaper).verifiseringsdato = current_date;
SELECT '04_before_apply_attr', status, id, ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '04_apply_attr_1', topo_update.apply_attr_on_topo_layer('{"properties":{"id":1,"reinbeitebruker_id":"ZH","fellesegenskaper.forstedatafangstdato":"2001-01-22","fellesegenskaper.verifiseringsdato":null,"slette_status_kode":0}}','topo_rein', 'reindrift_anlegg_linje','{"properties":{"status":"10","saksbehandler":"imi@nibio.no","fellesegenskaper.opphav":"NIBIO_TULL","fellesegenskaper.kvalitet.maalemetode":"82"}}');
SELECT '04_apply_attr_2', topo_update.apply_attr_on_topo_layer('{"properties":{"id":1,"anleggstype":5,"reinbeitebruker_id":"ZH","fellesegenskaper.forstedatafangstdato":"2001-01-22","fellesegenskaper.verifiseringsdato":null,"slette_status_kode":0}}','topo_rein', 'reindrift_anlegg_linje','{"properties":{"status":"10","saksbehandler":"imi@nibio.no","reinbeitebruker_id":"ZH","fellesegenskaper.opphav":"NIBIO_TULL","fellesegenskaper.kvalitet.maalemetode":"82"}}');
SELECT '04_after_apply', id, status, anleggstype, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
-- Check that update log has values for reindrift_anlegg_linje since the object in reindrift_anlegg_linje has reached a valid state
select '04_03_data_update_log', id, row_id, schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_linje' and change_confirmed_by_admin = false order by id asc;
-- Check that new data_update_log_new_v has values top accept for reindrift_anlegg_linje
select '04_03_data_update_log_new_v', id_before, json_before, id_after, schema_name,  table_name, operation_before, operation_after, data_row_state, 
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_linje' and json_after is not null and json_after::text <> '{}'::text order by  date_after desc limit 1;
SELECT '04_03_status_before_accept', id, status, ST_Length(ST_Transform(linje::geometry(MultiLineString,4258), 25833))::int as length, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
SET session_replication_role = replica; -- disable trigger for system update
-- Accept the changes reindrift_anlegg_linje
SELECT '04_03_layer_accept_update', * from  topo_update.layer_accept_update(3,'lop');
SET session_replication_role = DEFAULT; --enable defalt trigger 
-- Status should now have changhed reindrift_anlegg_linje
SELECT '04_03_status_after_accept', id, status, ST_Length(ST_Transform(linje::geometry(MultiLineString,4258), 25833))::int as length, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
-- There should be no more row to accept for reindrift_anlegg_linje
select '04_03_rows_after_accept', count(*) from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_linje' and json_after is not null and json_after::text <> '{}'::text;

-- ======= Create a new line that intersetcs with the object in layer reindrift_anlegg_linje and update it,   ======= --
SELECT '5', SUM(ST_Length(ST_Transform(geom::geometry(LineString,4258), 25833)))::int, count(*) from topo_rein_sysdata_ran.edge_data;
SELECT '6', SUM(ST_Length(ST_Transform(linje::geometry(MultiLineString,4258), 25833)))::int, count(*) from topo_rein.reindrift_anlegg_linje;
-- NB THe reason why we have differrents lengths here is that we have added directly to topo_rein_sysdata_ran.edge_data in a ealier test
SELECT '7', count(id) FROM (SELECT 1 AS id FROM  topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.700371,58.552619],[5.705207,58.552386]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '7_status_after', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date ORDER BY id;
SELECT '8', SUM(ST_Length(ST_Transform(geom::geometry(LineString,4258), 25833)))::int, count(*) from topo_rein_sysdata_ran.edge_data;
SELECT '9', SUM(ST_Length(ST_Transform(linje::geometry(MultiLineString,4258), 25833)))::int, count(*) from topo_rein.reindrift_anlegg_linje;
SELECT '9_status_after', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date ORDER BY id;
SELECT '10', count(id) FROM (SELECT 1 AS id FROM topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[15.9657743158,68.5173276573],[15.967341771,68.5175244919],[15.9707442177,68.5176731338],[15.973023534,68.5173234018],[15.9742820186,68.516710382],[15.9747133486,68.5160684285],[15.974409086,68.5153971067],[15.9733312891,68.5142292209],[15.9727112129,68.5130578708],[15.970050698,68.5124466358],[15.9661982366,68.5122599406],[15.9640955173,68.5121580206]]},"properties":{"reinbeitebruker_id":"XA","anleggstype":4,"felles_egenskaper.forstedatafangstdato":null,"felles_egenskaper.verifiseringsdato":"2015-01-01","felles_egenskaper.oppdateringsdato":null,"felles_egenskaper.opphav":"Reindriftsforvaltningen","felles_egenskaper.kvalitet.maalemetode":82}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '10_status_after', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date ORDER BY id;
SELECT '11', SUM(ST_Length(geom)), count(*) from topo_rein_sysdata.edge_data;
SELECT '12', t.id, ROUND(ST_Length(t.linje::geometry(MultiLineString,4258))::numeric,15), ST_Srid(t.linje::geometry(MultiLineString,4258)) from topo_rein.reindrift_anlegg_linje t;
SELECT '13', count(id) FROM (SELECT 1 AS id FROM topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751],[5.705207,58.552386]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '13_status_after', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date ORDER BY id;
SELECT '14', count(id) FROM (SELECT 1 AS id FROM topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751]]}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '14_status_after', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date  ORDER BY id;
SELECT '14_set_attr', topo_update.apply_attr_on_topo_line('{"properties":{"id":7,"reinbeitebruker_id":"ZH","fellesegenskaper.forstedatafangstdato":"2001-01-22","fellesegenskaper.verifiseringsdato":null,"slette_status_kode":0}}','topo_rein', 'reindrift_anlegg_linje', 'linje','{"properties":{"status":"0","saksbehandler":"imi@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"NIBIO_TULL","fellesegenskaper.kvalitet.maalemetode":"82"}}');
select '14_data_update_log', id, row_id, removed_by_splitt_operation, schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_linje' and removed_by_splitt_operation = false and change_confirmed_by_admin = false order by row_id,id asc;
-- Check that new data_update_log_new_v has values top accept for reindrift_anlegg_linje
select '14_data_update_log_new_v', id_before, id_after, schema_name, data_row_id, table_name, operation_before, operation_after, data_row_state, 
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_linje' and json_after is not null and json_after::text <> '{}'::text 
order by  date_after;
SELECT '14_status_before_accept', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date  ORDER BY id;
-- There should be no more row to accept for reindrift_anlegg_linje
SELECT '14_layer_accept_update', * from  topo_update.layer_accept_update(7,'lop');
-- Status should now have changhed reindrift_anlegg_linje
SELECT '14_status_after_accept', id, status, reinbeitebruker_id, anleggstype, ST_length(ST_Transform(t.linje::geometry(MultiLineString,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode FROM topo_rein.reindrift_anlegg_linje t WHERE (felles_egenskaper).oppdateringsdato = current_date  ORDER BY id;
-- There should be no more row to accept for reindrift_anlegg_linje

SELECT '15', t.id,  ROUND(ST_length(t.linje)::numeric,15) l1, ROUND( ST_Length(t.linje::geometry(MultiLineString,4258))::numeric,15), ST_Srid(t.linje::geometry(MultiLineString,4258)) from topo_rein.reindrift_anlegg_linje t order by id;
SELECT '16', count(id) FROM (SELECT 1 AS id FROM topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70182,58.55131],[5.70368,58.55134],[5.70403,58.553751],[5.705207,58.552386]]},"properties":{"Fellesegenskaper.Kvalitet.Maalemetode":82,"fellesegenskaper.forstedatafangstdato":"2016-01-01"}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;;
SELECT '16_01', (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '17', count(id) FROM (SELECT 1 AS id FROM topo_update.create_line_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[5.70513,58.55249],[5.70638,58.54978]]},"properties":{"Fellesegenskaper.Kvalitet.Maalemetode":82,"fellesegenskaper.forstedatafangstdato":"2016-01-01"}}','topo_rein', 'reindrift_anlegg_linje', 'linje', 1e-10)) AS R;
SELECT '17_01', (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_linje WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_linje) AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '18', t.id, status, ROUND(ST_length(t.linje)::numeric,15) l1, ROUND(ST_Length(t.linje::geometry(MultiLineString,4258))::numeric,15), ST_Srid(t.linje::geometry(MultiLineString,4258)) from topo_rein.reindrift_anlegg_linje t order by id;

-- ======= Continue work on a surface object in layer topo_rein.arstidsbeite_var_flate and update it,   ======= --
SELECT '19', id, status, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_var_flate;
SELECT '20_02', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","fellesegenskaper.forstedatafangstdato":"2001-01-22","fellesegenskaper.verifiseringsdato":null,"slette_status_kode":0}}','topo_rein', 'arstidsbeite_var_flate', 'omrade','{"properties":{"status":"0","saksbehandler":"imi@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"NIBIO"}}');
SELECT '20_03', (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate WHERE id = 1 AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '20_04', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":2,"fellesegenskaper.verifiseringsdato":"2015-01-01","slette_status_kode":0}}','topo_rein', 'arstidsbeite_var_flate', 'omrade','{"properties":{"status":"0","saksbehandler":"imi@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"NIBIO"}}');
SELECT '20_05', (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate WHERE id = 1 AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '21', id, status, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_var_flate;
SELECT '21_status_after', id, status, reinbeitebruker_id, reindrift_sesongomrade_kode, ST_Area(ST_Transform(t.omrade::geometry(MultiPolygon,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate t ORDER BY id;
select '21_data_update_log', id, row_id, removed_by_splitt_operation, schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log e where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and removed_by_splitt_operation = false and change_confirmed_by_admin = false;
-- Check that new data_update_log_new_v has values top accept for arstidsbeite_var_flate
select '21_data_update_log_new_v', id_before, json_before, id_after, schema_name, data_row_id, table_name, operation_before, operation_after, data_row_state, 
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and json_after is not null and json_after::text <> '{}'::text order by  date_after;
SELECT '21_status_before_accept', id, status, reinbeitebruker_id, reindrift_sesongomrade_kode, ST_Area(ST_Transform(t.omrade::geometry(MultiPolygon,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate t ORDER BY id;
-- There should be no more row to accept for arstidsbeite_var_flate
SET session_replication_role = replica; -- disable trigger for system update
-- Accept the changes reindrift_anlegg_linje
SELECT '21_layer_accept_update', * from  topo_update.layer_accept_update(12,'lop');
SET session_replication_role = DEFAULT; --enable defalt trigger 
-- Status should now have changhed arstidsbeite_var_flate
SELECT '21_status_after_accept', id, status, slette_status_kode, reinbeitebruker_id, reindrift_sesongomrade_kode, ST_Area(ST_Transform(t.omrade::geometry(MultiPolygon,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate t ORDER BY id;
-- There should be no more row to accept for arstidsbeite_var_flate
select '21_rows_after_accept', count(*) from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and json_after is not null and json_after::text <> '{}'::text;
-- Set flag for deeee 
SELECT '21_set_to_deleted', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"slette_status_kode":1}}','topo_rein', 'arstidsbeite_var_flate', 'omrade','{"properties":{"status":"10","saksbehandler":"imi@nibio.no","fellesegenskaper.opphav":"NIBIO"}}');
-- We set slette status code to 1, to indicate that the record is valid
SELECT '21_status_set_deleted_flag', id, status, slette_status_kode, reinbeitebruker_id, reindrift_sesongomrade_kode, ST_Area(ST_Transform(t.omrade::geometry(MultiPolygon,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate t ORDER BY id;
select '21_data_update_log_after_set_delete_flag', id, row_id, removed_by_splitt_operation, schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log e where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and removed_by_splitt_operation = false and change_confirmed_by_admin = false ORDER BY id;
-- Check that new data_update_log_new_v has values top accept for arstidsbeite_var_flate, in json_before the slette_status_kode should now be 0
select '21_data_update_log_new_v_after_set_delete_flag', id_before, id_after, schema_name, data_row_id, table_name, operation_before, operation_after, data_row_state, 
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_before_status ,
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_before_slette_status_kode ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_after_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_after_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and json_after is not null and json_after::text <> '{}'::text order by  date_after;
-- Check that update log has values for arstidsbeite_var_flate
select '21_data_update_log_after_delete', id, schema_name,  table_name, operation, 
status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_var_flate' and change_confirmed_by_admin is false order by  id  desc limit 3;

SELECT '21_layer_accept_update', * from  topo_update.layer_accept_update(14,'lop');

SELECT '21_status_after_accept_flag', id, status, slette_status_kode, reinbeitebruker_id, reindrift_sesongomrade_kode, ST_Area(ST_Transform(t.omrade::geometry(MultiPolygon,4258), 25833))::int , ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.arstidsbeite_var_flate t ORDER BY id;


-- Create point with all values set 
SELECT '22', count(id) FROM (SELECT 1 AS id FROM topo_update.create_point_point_domain_obj('{"type": "Feature","properties":{"fellesegenskaper.forstedatafangstdato":"2015-10-11","fellesegenskaper.verifiseringsdato":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.opphav":"Reindriftsforvaltningen"},"geometry":{"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[5.70182,58.55131]}}','topo_rein', 'reindrift_anlegg_punkt', 'punkt', 1e-10,'{"properties":{"saksbehandler":"user1","reinbeitebruker_id":"XA","anleggstype":10,"fellesegenskaper.opphav":"opphav ØÆÅøå"}}')) AS R;
-- Check values for created point in is correct
SELECT '22_01', id, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_punkt) AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '23', id, reinbeitebruker_id, punkt, (felles_egenskaper).opphav, saksbehandler   from topo_rein.reindrift_anlegg_punkt;
-- Check that update log has values for reindrift_anlegg_punkt since the object in reindrift_anlegg_punkt has reached a valid state
select '23_03_data_update_log', id, schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
--json_row_data#>'{objects,collection,geometries,0,properties,slette_status_kode}',
--json_row_data#>'{objects,collection,geometries,0,properties}'
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' order by  id  desc limit 2;
-- Check that new data_update_log_new_v has values top accept for reindrift_anlegg_punkt
select '23_03_data_update_log_new_v', id_before, id_after, schema_name,  table_name, operation_before, operation_after, data_row_state, 
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_before_status ,
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_before_slette_status_kode ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_after_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_after_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' and json_after is not null and json_after::text <> '{}'::text order by  date_after  desc limit 1;
SELECT '23_03_status_before_accept', id, status, punkt::geometry, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_punkt) AND (felles_egenskaper).oppdateringsdato = current_date;
-- Accept the changes reindrift_anlegg_punkt
SELECT '23_03_layer_accept_update', * from  topo_update.layer_accept_update(16,'lop');
-- Status should now have changhed reindrift_anlegg_punkt
SELECT '23_03_status_after_accept', id, status, punkt::geometry, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_punkt) AND (felles_egenskaper).oppdateringsdato = current_date;
-- There should be no more row to accept for reindrift_anlegg_punkt
select '23_03_rows_after_accept', count(*) from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' and json_after is not null and json_after::text <> '{}'::text;



UPDATE topo_rein.reindrift_anlegg_punkt set felles_egenskaper = '(2001-01-22,,"(,,)",2016-09-03,Landbruksdirektoratet,2015-01-01,,"(,)")' where id = 1;
SELECT '24_01', felles_egenskaper FROM topo_rein.reindrift_anlegg_punkt WHERE id = 1;
SELECT '24_02', topo_update.apply_attr_on_topo_point('{"type": "Feature","properties":{"id":1,"reinbeitebruker_id":"XI","reindrift_sesongomrade_kode":1,"fellesegenskaper.forstedatafangstdato":"2001-01-22","fellesegenskaper.verifiseringsdato":"2015-01-01","fellesegenskaper.oppdateringsdato":"2016-09-05","slette_status_kode":0}, "geometry":{"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[5.0,58.0]}}','topo_rein', 'reindrift_anlegg_punkt', 'punkt',  1e-10);
SELECT '24_03', (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = 1 AND (felles_egenskaper).oppdateringsdato = current_date;
SELECT '25', id, reinbeitebruker_id, punkt  from topo_rein.reindrift_anlegg_punkt;
SELECT '25A', count(editable) FROM topo_rein.reindrift_anlegg_topojson_punkt_v;
SELECT '26', topo_update.delete_topo_point(1,'topo_rein', 'reindrift_anlegg_punkt', 'punkt');
SELECT '27', id, reinbeitebruker_id, punkt  from topo_rein.reindrift_anlegg_punkt;


-- Create a sutrface 
SELECT '28', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10)) AS R;
SELECT '29', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status  from topo_rein.arstidsbeite_sommer_flate;
SELECT '30', count(*) from topo_rein.arstidsbeite_sommer_flate;
-- Set attributtes
SELECT '31', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":4,"fellesegenskaper.forstedatafangstdato":"2014-10-11","felles_egenskaper.verifiseringsdato":"2015-01-01"}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade');
SELECT '32', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status,(felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato  from topo_rein.arstidsbeite_sommer_flate;
--Add new polygon this surface 
SELECT '32_1', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","properties":{"reinbeitebruker_id":"XI","reindrift_sesongomrade_kode":1},"geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.33500,69.20970],[18.37686,69.22246],[18.34102,69.19811]]}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,'{"properties":{"reinbeitebruker_id":"ZA"}}')) AS R;
-- Check that the old is not changed
SELECT '32_2A', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status,(felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato  from topo_rein.arstidsbeite_sommer_flate where id = 1;
-- Check tht new status is 0  
SELECT '32_2B', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status  from topo_rein.arstidsbeite_sommer_flate where id = 2 and (felles_egenskaper).forstedatafangstdato = CURRENT_DATE and (felles_egenskaper).verifiseringsdato = CURRENT_DATE ;
-- create a hole in this polygon (craete a surface and delete it)
SELECT '32_3', topo_update.delete_topo_surface((SELECT ((SELECT * FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.340281,69.21086],[18.3536658335307,69.2066558329758],[18.3318345167625,69.1987665997243],[18.3210217330378,69.2029603714597],[18.338227,69.209054],[18.340281,69.21086]]}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10))::json->1)::json->'id')::text::int,
'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense');
-- Add new polygon crosses this hole
SELECT '32_4', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","properties":{"reinbeitebruker_id":"XI","reindrift_sesongomrade_kode":1},"geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3280037021665,69.2052819683587],[18.3259630939192,69.2058277962915],[18.3308917879818,69.2079652996634],[18.3337429119852,69.2071903313823],[18.3459575177129,69.2038702611246],[18.3485458015754,69.2031667358155],[18.3436457100541,69.2010979977988],[18.3405657643562,69.2019218307887],[18.3280037021665,69.2052819683587]]}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,'{"properties":{"reinbeitebruker_id":"ZA"}}')) AS R;
-- Check number of rows
-- This  fails with postgres 11 and postgis 2.5 ????
-- SELECT '32_5', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status  from topo_rein.arstidsbeite_sommer_flate order by id;
-- This is the result from postgres 11 and postgis 2.5
-- 32_5|2|ZH|4|(4,2,2,3)|0
-- 32_5|5|ZH|4|(4,2,5,3)|1
-- 32_5|6|ZH|4|(4,2,6,3)|1
-- 32_5|7|ZH|4|(4,2,7,3)|0
-- 32_5|8|||(4,2,8,3)|0
-- 32_5|9|ZH|4|(4,2,9,3)|1
-- 32_5|10|||(4,2,10,3)|0


SELECT '33', count(id) FROM (SELECT 1 AS id FROM topo_update.create_nocutline_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[15.9657743158,68.5173276573],[15.967341771,68.5175244919],[15.9707442177,68.5176731338],[15.973023534,68.5173234018],[15.9742820186,68.516710382],[15.9747133486,68.5160684285],[15.974409086,68.5153971067],[15.9733312891,68.5142292209],[15.9727112129,68.5130578708],[15.970050698,68.5124466358],[15.9661982366,68.5122599406],[15.9640955173,68.5121580206]]},"properties":{"reinbeitebruker_id":"XA","felles_egenskaper.forstedatafangstdato":null,"felles_egenskaper.verifiseringsdato":"2015-01-01","felles_egenskaper.oppdateringsdato":null,"felles_egenskaper.opphav":"Reindriftsforvaltningen","felles_egenskaper.kvalitet.maalemetode":82}}','topo_rein', 'rein_trekklei_linje', 'linje', 1e-10)) AS R;
SELECT '34', id, reinbeitebruker_id, linje  from topo_rein.rein_trekklei_linje;
SELECT '35', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'arstidsbeite_host_flate', 'omrade', 'arstidsbeite_host_grense','grense',  1e-10)) AS R;
SELECT '36', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_host_flate;
SELECT '37', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":5}}','topo_rein', 'arstidsbeite_host_flate', 'omrade');
SELECT '38', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_host_flate;
SELECT '39', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'arstidsbeite_hostvinter_flate', 'omrade', 'arstidsbeite_hostvinter_grense','grense',  1e-10)) AS R;
SELECT '40', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_hostvinter_flate;
SELECT '41', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":7}}','topo_rein', 'arstidsbeite_hostvinter_flate', 'omrade');
SELECT '42', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_hostvinter_flate;
SELECT '43', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'arstidsbeite_vinter_flate', 'omrade', 'arstidsbeite_vinter_grense','grense',  1e-10)) AS R;
SELECT '44', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_vinter_flate;
SELECT '45', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":9}}','topo_rein', 'arstidsbeite_vinter_flate', 'omrade');
SELECT '46', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_vinter_flate;
SELECT '47', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'beitehage_flate', 'omrade', 'beitehage_grense','grense',  1e-10)) AS R;
SELECT '48', id, reinbeitebruker_id, reindriftsanleggstype, omrade  from topo_rein.beitehage_flate;
SELECT '49', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"reinbeitebruker_id":"ZH","reindriftsanleggstype":3}}','topo_rein', 'beitehage_flate', 'omrade');
SELECT '50', id, reinbeitebruker_id, reindriftsanleggstype, omrade  from topo_rein.beitehage_flate;
SELECT '51', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]}}','topo_rein', 'oppsamlingsomrade_flate', 'omrade', 'oppsamlingsomrade_grense','grense',  1e-10)) AS R;
SELECT '52', id, reinbeitebruker_id, omrade  from topo_rein.oppsamlingsomrade_flate;
SELECT '53', count(id) FROM (SELECT 1 AS id FROM  topology.toTopoGeom(ST_GeomFromText('LINESTRING(14.43537903 66.07564708,14.4351923259169 66.0761789190405)',4258), 'topo_rein_sysdata_rhs', (SELECT layer_id from topology.layer where table_name = 'arstidsbeite_hostvinter_grense')::integer, 1e-10)) AS R;
SELECT '54', count(id) FROM (SELECT 1 AS id FROM  topology.toTopoGeom(ST_GeomFromText('LINESTRING(14.52875444 66.09555452,14.52992389 66.09211295,14.52979138 66.09210358,14.52917258 66.09208375,14.52853599 66.0918306,14.52818337 66.09176672,14.52769524 66.09185495,14.52732351 66.09162952,14.5269099 66.09127836,14.52659851 66.09137609,14.52609078 66.09132967,14.52571355 66.09140029,14.52533766 66.09139914,14.52472625 66.09098456,14.52459627 66.09084061,14.52501805 66.09075219,14.5257266 66.09070054,14.52583799 66.09065602,14.52506898 66.09039348,14.52438624 66.09024783,14.524236 66.09000513,14.52357639 66.08980572,14.52333654 66.08962555,14.52324777 66.08964322,14.52298447 66.08953474,14.52256489 66.08950653,14.52207982 66.08943326,14.52173046 66.08919891,14.52102853 66.08890067,14.52096474 66.0887659,14.52132271 66.08854272,14.52097167 66.08839808,14.5205965 66.08836103,14.52041827 66.08843225,14.52032831 66.08851272,14.52017304 66.08853915,14.52010841 66.08844923,14.51988868 66.08837677,14.51978101 66.08822392,14.51996076 66.08807196,14.52009392 66.08804546,14.5204463 66.08811833,14.52095395 66.08816476,14.52115479 66.0880667,14.52129048 66.08790562,14.52155983 66.08769114,14.52141098 66.08737667,14.52108527 66.08706165,14.5209096 66.0869983,14.52078101 66.08678258,14.5201686 66.08643078,14.52048521 66.08605495,14.52126333 66.0858241,14.52175187 66.08570899,14.52281112 66.08581095,14.52296738 66.08573069,14.52270901 66.08536205,14.52385819 66.08538354,14.5241459 66.08536648,14.52419515 66.08509748,14.52363014 66.08457538,14.52339102 66.08435932,14.52268853 66.08409698,14.52260247 66.08397111,14.52227427 66.08379066,14.52165567 66.0837708,14.52145842 66.08368047,14.5215713 66.08355522,14.52183892 66.08343044,14.52210451 66.08341332,14.52210704 66.08327875,14.52243742 66.08334258,14.52252668 66.08329799,14.52239995 66.08298359,14.52174476 66.08255989,14.52025017 66.08210667,14.52025524 66.08183754,14.51968327 66.08169221,14.51891137 66.08160009,14.51860142 66.08162604,14.5180514 66.08148975,14.51798764 66.08135497,14.51759354 66.08115636,14.51684495 66.08100151,14.51684665 66.08091179,14.51706853 66.08086763,14.51735824 66.08074293,14.51751397 66.08068959,14.51765169 66.08042087,14.51745788 66.08015111,14.51719487 66.08003365,14.51563045 66.07977755,14.51541149 66.0796692,14.51552934 66.07928378,14.51524494 66.07913037,14.51504518 66.0791746,14.51436125 66.07910965,14.51462869 66.07899386,14.51454199 66.07890387,14.51407789 66.07890241,14.51372908 66.0786501,14.51296227 66.07829779,14.51195187 66.07797162,14.51184498 66.07778287,14.51149449 66.07762027,14.51129646 66.07757479,14.51094563 66.07743013,14.51083772 66.07729521,14.51053109 66.07715069,14.51017837 66.07710472,14.50995652 66.07714887,14.50881257 66.07687608,14.50863492 66.07692038,14.50737755 66.07679974,14.50700657 66.07655632,14.50667544 66.07653732,14.50661193 66.07639357,14.50639181 66.076348,14.50623921 66.07623985,14.50586633 66.07609511,14.50573392 66.07608572,14.50544455 66.07619245,14.50485105 66.07602906,14.50465234 66.07601945,14.50451766 66.07612668,14.50429528 66.07619774,14.50319878 66.07576357,14.50293449 66.07571786,14.50235907 66.07576087,14.50141203 66.07559632,14.50121351 66.07557773,14.49982648 66.07531307,14.49863587 66.07517463,14.49750715 66.07526068,14.49596247 66.07514798,14.49424478 66.0748463,14.49276536 66.07478761,14.4917983 66.07452425,14.49107126 66.07441419,14.49071682 66.07445788,14.49049676 66.0744123,14.49025423 66.07438458,14.48978913 66.07443688,14.48939229 66.07439071,14.48873408 66.07415526,14.48851348 66.07413659,14.4883791 66.07422586,14.48817933 66.07427006,14.48645564 66.07427331,14.48550749 66.07417146,14.48495127 66.07435801,14.48429129 66.07421226,14.48373924 66.07419247,14.48322775 66.07435225,14.48210083 66.07434848,14.4816611 66.07423934,14.48080209 66.07410188,14.48020054 66.07434209,14.47825404 66.07443421,14.47697521 66.07429531,14.47688517 66.07437575,14.4768592 66.07456407,14.47608305 66.07469601,14.47533231 66.07466655,14.47398683 66.07454534,14.47244082 66.07450418,14.47177978 66.0744122,14.47038771 66.07440743,14.46961228 66.07450346,14.46846663 66.07433802,14.4672504 66.07437869,14.46671839 66.0744576,14.46590063 66.07446374,14.46510271 66.07457762,14.46496579 66.07478349,14.46356292 66.07529001,14.46248016 66.07528625,14.46192489 66.07541889,14.46121968 66.07532671,14.4608425 66.07539717,14.46044418 66.0754227,14.4602876 66.07551187,14.45999995 66.0755288,14.45828113 66.07529849,14.45716126 66.0749626,14.45665418 66.07490698,14.45543617 66.0750283,14.45463684 66.07520491,14.45399372 66.0753103,14.45220365 66.07531293,14.45122712 66.07550684,14.4505863 66.07550456,14.45005655 66.07547576,14.44767433 66.07526988,14.44644119 66.07506808,14.44599964 66.07504855,14.44571023 66.07514621,14.44524639 66.07513557,14.44513297 66.07526974,14.44482224 66.07533142,14.44459873 66.07544725,14.44409461 66.07525703,14.44290451 66.07510919,14.44089428 66.07507501,14.44034028 66.07514478,14.43963022 66.07527678,14.43960516 66.07541126,14.43858572 66.07554214,14.43792518 66.07543207,14.43730745 66.07538496,14.43608614 66.07564966,14.43535693 66.075647,14.4351905 66.07617572,14.43525361 66.0763195,14.43522812 66.07647193,14.43466989 66.07673007,14.43446602 66.07695362,14.43467903 66.07731327,14.43431748 66.07767082,14.43373571 66.07799167,14.43368892 66.07810813,14.43338364 66.07891447,14.43322395 66.07913818,14.43321215 66.07966748,14.43264703 66.08023062,14.43263663 66.08069712,14.43212308 66.0809285,14.43141587 66.08191279,14.43134254 66.08222654,14.43089385 66.08252095,14.43066579 66.08283413,14.43058141 66.08364128,14.43121405 66.08500732,14.43292198 66.08673619,14.43441943 66.08799773,14.43617438 66.08961907,14.43893908 66.09258982,14.44237515 66.09523099,14.44732191 66.09759937,14.45092152 66.09990898,14.45198638 66.10079199,14.45451142 66.10167119,14.45641259 66.10173172,14.45925198 66.10136487,14.46506361 66.10061353,14.46858507 66.10041036,14.47412503 66.09993587,14.48550186 66.09849383,14.49035762 66.09790882,14.49671921 66.09722091,14.49990926 66.09696212,14.50316576 66.0966945,14.50804081 66.09621666,14.51582206 66.09642067)',4258), 'topo_rein_sysdata_rhs', (SELECT layer_id from topology.layer where table_name = 'arstidsbeite_hostvinter_grense')::integer, 1e-10)) AS R;

-- Create a sutrface 
SELECT '55_1', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[19.3342803675,70.1937360885],[19.3248972004,70.1926352514],[19.3225223088,70.1928235904],[19.3172506318,70.1941599626],[19.3145519815,70.1957316656],[19.3123602886,70.1980059858],[19.310704822,70.2011722899],[19.3080083628,70.2036461481],[19.3052533657,70.2074983075],[19.3057756447,70.2082956989],[19.3075330509,70.2093067972],[19.3103134457,70.2100132313],[19.3156403748,70.2107656476],[19.3228118186,70.2113399389],[19.3301412606,70.2111984614],[19.3349532259,70.2112004097],[19.3395639862,70.2116335442],[19.3433515794,70.2127948707],[19.3502828982,70.2152724054],[19.3524811669,70.2156570867],[19.3547763375,70.2158024362],[19.3580354423,70.2152640418],[19.3623692173,70.2138971761],[19.3678152295,70.2110837518],[19.3695071064,70.2082009883],[19.3680734909,70.2067092134],[19.3638755844,70.2028967661],[19.355530639,70.1981677188],[19.3471464882,70.1957662158],[19.3342803675,70.1937360885]]},"properties":{"reinbeitebruker_id":"ZD","fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2018-10-10","fellesegenskaper.forstedatafangstdato":"2018-10-10"}}','topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense',  1e-10)) AS R;
SELECT '55_2', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, ST_area(ST_transform(omrade::geometry,32633))::integer, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).forstedatafangstdato, status  from topo_rein.arstidsbeite_var_flate WHERE id = (select max(id) FROM topo_rein.arstidsbeite_var_flate) order by id;
-- Set attributtes, NB set fellesegenskaper.forstedatafangstdato only used when null in the database 
SELECT '55_4', topo_update.apply_attr_on_topo_line('{"properties":{"id":2,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":2,"fellesegenskaper.verifiseringsdato":"2017-11-22","fellesegenskaper.forstedatafangstdato":"2017-11-20"}}','topo_rein', 'arstidsbeite_var_flate', 'omrade');
SELECT '55_5', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, ST_area(ST_transform(omrade::geometry,32633))::integer, status, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).forstedatafangstdato  from topo_rein.arstidsbeite_var_flate WHERE id = (select max(id) FROM topo_rein.arstidsbeite_var_flate) order by id;
--set attributtes but no fellesegenskaper
SELECT '55_4_b', topo_update.apply_attr_on_topo_line('{"properties":{"id":2,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":2}}','topo_rein', 'arstidsbeite_var_flate', 'omrade');
SELECT '55_5_b', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, ST_area(ST_transform(omrade::geometry,32633))::integer, status, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).forstedatafangstdato  from topo_rein.arstidsbeite_var_flate WHERE id = (select max(id) FROM topo_rein.arstidsbeite_var_flate) order by id;

--Add hole in this surface 
SELECT '55_6', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","properties":{"reinbeitebruker_id":"XI","reindrift_sesongomrade_kode":1},"geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[19.3280037021665,70.2052819683587],[19.3259630939192,70.2058277962915],[19.3308917879818,70.2079652996634],[19.3337429119852,70.2071903313823],[19.3459575177129,70.2038702611246],[19.3485458015754,70.2031667358155],[19.3436457100541,70.2010979977988],[19.3405657643562,70.2019218307887],[19.3280037021665,70.2052819683587]]}}','topo_rein', 'arstidsbeite_var_flate', 'omrade', 'arstidsbeite_var_grense','grense',  1e-10,'{"properties":{"reinbeitebruker_id":"ZA","fellesegenskaper.verifiseringsdato":"2018-11-22","fellesegenskaper.forstedatafangstdato":"2018-11-20"}}')) AS R;
SELECT '55_7', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).forstedatafangstdato  from topo_rein.arstidsbeite_var_flate WHERE id > (select max(id)-2 FROM topo_rein.arstidsbeite_var_flate) order by id;
SELECT '55_8', id, grense, ST_Length(ST_transform(grense::geometry,32633))::integer  from topo_rein.arstidsbeite_var_grense WHERE id > (select max(id)-2 FROM topo_rein.arstidsbeite_var_grense) order by id;

-- 55_* : Test that surface attributtes from client is used and not the attrubuttes from the existing surface 
-- Draw line tha creates a surface (polgon) 
SELECT '55_1', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[518043.16996098636,7834780.601250791],[518196.14160128165,7825585.128504733],[528206.0093870214,7829364.882725497],[517603.88101841486,7834041.287307017]],"crs":{"type":"name","properties":{"name":"EPSG:25835"}}},"properties":{"reinbeitebruker_id":"ZD","fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2019-01-03","fellesegenskaper.forstedatafangstdato":"2019-01-03"}}','topo_rein', 'arstidsbeite_host_flate', 'omrade', 'arstidsbeite_host_grense','grense',  1e-10)) AS R;
-- Check the value for the surface object created
SELECT '55_2', id, reinbeitebruker_id, reindrift_sesongomrade_kode,  ST_area(ST_transform(omrade::geometry,32633))::integer, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).forstedatafangstdato, status from topo_rein.arstidsbeite_host_flate where id= (select max(id) from topo_rein.arstidsbeite_host_flate);
-- Update surface values new values
SELECT '55_3', topo_update.apply_attr_on_topo_line('{"properties":{"id":2,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":5}}','topo_rein', 'arstidsbeite_host_flate', 'omrade');
-- Check the surface values updated
SELECT '55_4', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_host_flate where id= (select max(id) from topo_rein.arstidsbeite_host_flate);
-- Extend this surface
SELECT '55_5', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type":"Feature","geometry":{"type":"LineString","coordinates":[[519275.98297216033,7831985.975850177],[524826.2885011948,7840479.82762988],[524661.168141182,7830498.936046706]],"crs":{"type":"name","properties":{"name":"EPSG:25835"}}},"properties":{"reinbeitebruker_id":"ZD","fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":822,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.verifiseringsdato":"2019-01-08","fellesegenskaper.forstedatafangstdato":"2019-01-08"}}','topo_rein', 'arstidsbeite_host_flate', 'omrade', 'arstidsbeite_host_grense','grense',  1e-10)) AS R;
SELECT '55_6', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_host_flate where id= (select (max(id)-1) from topo_rein.arstidsbeite_host_flate);
SELECT '55_7', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade  from topo_rein.arstidsbeite_host_flate where id= (select max(id) from topo_rein.arstidsbeite_host_flate);



-- Create point with all values set and eject it
SELECT '58', count(id) FROM (SELECT 1 AS id FROM topo_update.create_point_point_domain_obj('{"type": "Feature","properties":{"fellesegenskaper.forstedatafangstdato":"2015-10-11","fellesegenskaper.verifiseringsdato":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.opphav":"Reindriftsforvaltningen"},"geometry":{"type":"Point","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[5.70182,58.55131]}}','topo_rein', 'reindrift_anlegg_punkt', 'punkt', 1e-10,'{"properties":{"saksbehandler":"user1","reinbeitebruker_id":"XA","anleggstype":10,"fellesegenskaper.opphav":"opphav ØÆÅøå"}}')) AS R;
-- Check that update log has values for reindrift_anlegg_punkt since the object in reindrift_anlegg_punkt has reached a valid state
select '58_03_data_update_log', schema_name,  table_name, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
--json_row_data#>'{objects,collection,geometries,0,properties,slette_status_kode}',
--json_row_data#>'{objects,collection,geometries,0,properties}'
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' order by  id  desc limit 2;
-- Check that new data_update_log_new_v has values top accept for reindrift_anlegg_punkt
select '58_03_data_update_log_new_v', id_before, json_before, id_after, schema_name,  table_name, operation_before, operation_after, data_row_state, 
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_before_status ,
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_before_slette_status_kode ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_after_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_after_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' 
and json_after is not null and json_after::text <> '{}'::text order by  date_after  desc limit 1;
SELECT '58_03_status_before_reject', id, status, slette_status_kode, punkt::geometry, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_punkt) AND (felles_egenskaper).oppdateringsdato = current_date;
-- Reject the changes reindrift_anlegg_punkt
SELECT '58_03_layer_reject_update', * from  topo_update.layer_reject_update(43,'lop');
-- Status and slette_status_kode should now have changhed reindrift_anlegg_punkt
SELECT '58_03_status_after_rejct', id, status, slette_status_kode, punkt::geometry, ((felles_egenskaper).kvalitet).maalemetode, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato FROM topo_rein.reindrift_anlegg_punkt WHERE id = (select max(id) FROM topo_rein.reindrift_anlegg_punkt) AND (felles_egenskaper).oppdateringsdato = current_date;
-- There should be no more row to accept for reindrift_anlegg_punkt
select '58_03_rows_after_reject', count(*) from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'reindrift_anlegg_punkt' and json_after is not null and json_after::text <> '{}'::text;

-- Create  sommer surface and set attributtes
SELECT '59_sommer_new', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[568867.7728054206,7900721.05851012],[568889.0217741862,7889496.242009791],[580091.0533080081,7895859.369156453],[567627.1981289758,7898016.421485742]]}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10)) AS R;
SELECT '59_sommer_set', topo_update.apply_attr_on_topo_line('{"properties":{"id":11,"status":10,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":4}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade');
SELECT '59_sommer_r2', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status from topo_rein.arstidsbeite_sommer_flate order by id desc limit 1;

-- Check update log after new surface
select '59_sommer_data_update_log_c2', count(*) from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_sommer_flate';
select '59_sommer_data_update_log_r2', id, schema_name,  table_name, row_id, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_sommer_flate' and row_id = 11 order by  id;
select '59_data_update_log_new_v', id_before, id_after, schema_name,  table_name, operation_before, operation_after, data_row_state, 
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_before_status ,
(json_before->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_before_slette_status_kode ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_after_status ,
(json_after->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_after_slette_status_kode 
from topo_rein.data_update_log_new_v where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_sommer_flate' and data_row_id = 11;

-- Accept the changes reindrift_anlegg_linje

SELECT '59_layer_accept_update', * from  topo_update.layer_accept_update(48,'lop');

-- Check update log after after accpet surface
select '59_sommer_data_update_log_c3', count(*) from topo_rein.data_update_log where  schema_name = 'topo_rein' and table_name = 'arstidsbeite_sommer_flate' and row_id = 1 and removed_by_splitt_operation = false and change_confirmed_by_admin = false;
update topo_rein.arstidsbeite_sommer_flate set felles_egenskaper.forstedatafangstdato = '2013-08-26';
update topo_rein.arstidsbeite_sommer_flate set felles_egenskaper.verifiseringsdato = '2015-07-26';
update topo_rein.arstidsbeite_sommer_flate set felles_egenskaper.oppdateringsdato = '2016-07-26';
update topo_rein.arstidsbeite_sommer_flate set felles_egenskaper.opphav = 'ole';

SELECT '59_sommer_r3', id, reinbeitebruker_id, reindrift_sesongomrade_kode, status, (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato, (felles_egenskaper).oppdateringsdato  from topo_rein.arstidsbeite_sommer_flate order by id desc limit 2;

-- Split the created surface in two
SELECT '59_sommer_split', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj(
'{"type":"Feature","geometry":{"type":"LineString","coordinates":[[572358.582674182,7902771.102496703],[572960.1837898717,7891010.480783969]],"crs":{"type":"name","properties":{"name":"EPSG:4258"}}},"properties":{"fellesegenskaper.kvalitet.maalemetode":82}}',
'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,
'{"properties":{"status":"10","saksbehandler":"distrikt.zd@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"Distrikt"}}')) AS R;

-- Split polygon to the left one more time (should have caused an error in function_01_topo_touches but it did not happen, so we have to check this one more time)
SELECT '59_sommer_split_b', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj(
'{"type":"Feature","geometry":{"type":"LineString","coordinates":[[572076,7894014],[577968,7896526]],"crs":{"type":"name","properties":{"name":"EPSG:4258"}}},"properties":{"fellesegenskaper.kvalitet.maalemetode":82}}',
'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,
'{"properties":{"status":"10","saksbehandler":"distrikt.zd@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"Distrikt"}}')) AS R;

-- Check that forstedatafangstdato and verifiseringsdato is not updated
-- Check that is oppdateringsdato is updated
SELECT '59_sommer_r4', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_rein.arstidsbeite_sommer_flate where (felles_egenskaper).oppdateringsdato = current_date or (felles_egenskaper).oppdateringsdato = '2016-07-26' order by id desc limit 3;

SELECT '59_sommer_data_update_log_r4', id, schema_name,  table_name, row_id, operation, status, 
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'status') as json_status ,
(json_row_data->'objects'->'collection'->'geometries'->0->'properties'->'slette_status_kode') as json_slette_status_kode 
from topo_rein.data_update_log 
where schema_name = 'topo_rein' and table_name = 'arstidsbeite_sommer_flate' and  row_id > 11 and removed_by_splitt_operation = false and change_confirmed_by_admin = false order by  id;

-- Create test sr5 flate
SELECT '60_init', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj('{"type": "Feature","geometry":{"type":"LineString","crs":{"type":"name","properties":{"name":"EPSG:4258"}},"coordinates":[[18.3342803675,69.1937360885],[18.3248972004,69.1926352514],[18.3225223088,69.1928235904],[18.3172506318,69.1941599626],[18.3145519815,69.1957316656],[18.3123602886,69.1980059858],[18.310704822,69.2011722899],[18.3080083628,69.2036461481],[18.3052533657,69.2074983075],[18.3057756447,69.2082956989],[18.3075330509,69.2093067972],[18.3103134457,69.2100132313],[18.3156403748,69.2107656476],[18.3228118186,69.2113399389],[18.3301412606,69.2111984614],[18.3349532259,69.2112004097],[18.3395639862,69.2116335442],[18.3433515794,69.2127948707],[18.3502828982,69.2152724054],[18.3524811669,69.2156570867],[18.3547763375,69.2158024362],[18.3580354423,69.2152640418],[18.3623692173,69.2138971761],[18.3678152295,69.2110837518],[18.3695071064,69.2082009883],[18.3680734909,69.2067092134],[18.3638755844,69.2028967661],[18.355530639,69.1981677188],[18.3471464882,69.1957662158],[18.3342803675,69.1937360885]]},"properties":{"avgrensing_type":9300,"fellesegenskaper.opphav":null,"fellesegenskaper.kvalitet.synbarhet":null,"fellesegenskaper.kvalitet.noyaktighet":null,"fellesegenskaper.kvalitet.maalemetode":null,"fellesegenskaper.oppdateringsdato":null,"fellesegenskaper.forstedatafangstdato":"2016-01-01","fellesegenskaper.verifiseringsdato":"1992-07-18","fellesegenskaper.Kvalitet.Maalemetode":82,"fellesegenskaper.opphav":"NIBIO"}}','topo_ar5', 'webclient_flate', 'omrade', 'webclient_grense','grense',  1e-10)) AS R;
SELECT '60_res_01', id, reinbeitebruker_id,arealtype, treslag, skogbonitet , grunnforhold, omrade, status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_ar5.webclient_flate where (felles_egenskaper).oppdateringsdato = current_date or (felles_egenskaper).oppdateringsdato =  current_date order by id desc limit 3;
SELECT '60_res_02', id, saksbehandler, avgrensing_type, (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_ar5.webclient_grense grense order by id desc limit 1;
SELECT '61_upd_01', topo_update.apply_attr_on_topo_line('{"properties":{"id":1,"status":1,"arealtype":11,"fellesegenskaper.verifiseringsdato":"2017-11-22","fellesegenskaper.forstedatafangstdato":"2017-11-20"}}','topo_ar5', 'webclient_flate','omrade');
SELECT '61_res_02', id, reinbeitebruker_id,arealtype, treslag, skogbonitet , grunnforhold, omrade, status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato from topo_ar5.webclient_flate where (felles_egenskaper).oppdateringsdato = current_date or (felles_egenskaper).oppdateringsdato =  current_date order by id desc limit 3;



-- Create a simple closed polygon
SELECT '62_sommer_closed_r1', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj(
'{"type":"Feature","geometry":{"type":"LineString","coordinates":[[19.2566862806899,69.9728016344656],[19.061380935077,69.9719838363748],[19.1524713810463,69.9005671594361],[19.2031159830381,69.980428365885]]
,"crs":{"type":"name","properties":{"name":"EPSG:4258"}}},"properties":{"fellesegenskaper.kvalitet.maalemetode":82}}',
'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,
'{"properties":{"status":"10","saksbehandler":"distrikt.zd@nibio.no","reinbeitebruker_id":null,"fellesegenskaper.opphav":"Distrikt","reinbeitebruker_id":"ZH"}}')) AS R;

--SELECT ST_AsText(ST_transform(ST_SetSrid(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[662580.2500028815,7768517.381560434],[655136.6182104762,7767917.398673603],[659153.5005698197,7760203.668569494],[660478.4073418331,7769224.159768911]]}'),32633),4258)) As wkt;
--SELECT ST_AsGeoJson(ST_transform(ST_SetSrid(ST_GeomFromGeoJSON('{"type":"LineString","coordinates":[[663856.5975224273,7764257.187557388],[656304.4440326836,7762412.651827327],[655426.2422869034,7757768.136219037],[662695.3390156106,7757784.899782651],[663058.4064553657,7764394.05016712]]}'),32633),4258)) As wkt;


SELECT '62_sommer_update_r1', topo_update.apply_attr_on_topo_line('{"properties":{"id":16,"status":1,"reinbeitebruker_id":"ZH","reindrift_sesongomrade_kode":4,"fellesegenskaper.verifiseringsdato":"2017-11-22","fellesegenskaper.forstedatafangstdato":"2017-11-20"}}','topo_rein', 'arstidsbeite_sommer_flate', 'omrade');

SELECT '62_sommer_closed_r1', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, 
ST_area(ST_transform(omrade::geometry,3035))::integer as area, 
status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_rein.arstidsbeite_sommer_flate where (felles_egenskaper).oppdateringsdato = current_date order by id desc limit 1;

SELECT '62_sommer_closed_r2', count(id) FROM (SELECT 1 AS id FROM topo_update.create_surface_edge_domain_obj(
'{"type":"Feature","geometry":{"type":"LineString","coordinates":[[19.2821685336156,69.9339049529857],[19.0822259656477,69.922047410019],[19.0513191478947,69.8810279567446],[19.2401888463084,69.8767530548273],[19.2616309004501,69.9356296334007]]
,"crs":{"type":"name","properties":{"name":"EPSG:4258"}}},"properties":{"fellesegenskaper.kvalitet.maalemetode":82,"fellesegenskaper.verifiseringsdato":"2017-12-22","fellesegenskaper.forstedatafangstdato":"2017-12-20","reinbeitebruker_id":"ZD"}}',
'topo_rein', 'arstidsbeite_sommer_flate', 'omrade', 'arstidsbeite_sommer_grense','grense',  1e-10,
'{"properties":{"status":"10","saksbehandler":"distrikt.zd@nibio.no","fellesegenskaper.opphav":"Distrikt","reinbeitebruker_id":null}}')) AS R;
-- check that old dates are ok
SELECT '62_sommer_closed_r2', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, 
ST_area(ST_transform(omrade::geometry,3035))::integer as area, 
status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_rein.arstidsbeite_sommer_flate where (felles_egenskaper).oppdateringsdato = current_date and (felles_egenskaper).forstedatafangstdato = '2017-11-20' order by id desc limit 2;

-- check area is ok
SELECT '62_sommer_closed_r2_sum', sum(area) from ( select id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, ST_area(ST_transform(omrade::geometry,32633))::integer as area, status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_rein.arstidsbeite_sommer_flate where (felles_egenskaper).oppdateringsdato = current_date and (felles_egenskaper).forstedatafangstdato = '2017-11-20' order by id desc limit 2) as t;

-- check that new dates are ok
SELECT '62_sommer_closed_r3', id, reinbeitebruker_id, reindrift_sesongomrade_kode, omrade, 
ST_area(ST_transform(omrade::geometry,32633))::integer as area, 
status,  (felles_egenskaper).opphav, (felles_egenskaper).forstedatafangstdato, (felles_egenskaper).verifiseringsdato from topo_rein.arstidsbeite_sommer_flate where (felles_egenskaper).oppdateringsdato = current_date and (felles_egenskaper).forstedatafangstdato = '2017-12-20' order by id desc limit 3;


