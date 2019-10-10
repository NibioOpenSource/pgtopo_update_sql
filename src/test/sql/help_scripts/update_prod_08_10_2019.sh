# add /Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/import_script/schema_org_rein_sosi_dump.sql
# add /Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/roles_topo_rein.sql

echo 'drop table topo_rein.rls_role_mapping cascade;' > /tmp/trein.sql

echo 'drop function if exists org_rein_sosi_dump.date2001_01_01_if_null(date) cascade;' >> /tmp/trein.sql
echo 'drop function if exists org_rein_sosi_dump.get_kvalitet_value(character varying,integer);' >> /tmp/trein.sql 
echo 'drop function if exists org_rein_sosi_dump.allebeitebrukerids(character varying,character varying,character varying) cascade;' >> /tmp/trein.sql 
echo 'drop function if exists topo_update.create_nocutline_edge_domain_obj(text,text,text,text,double precision,text) cascade;' >> /tmp/trein.sql 
echo 'drop function if exists  org_rein_sosi_dump.simplefeature_2_topo_surface(text,text,text,text,text,text,text,double precision,geometry) cascade;' >> /tmp/trein.sql 
echo 'drop type topo_update.json_input_structure cascade;' >> /tmp/trein.sql 
echo 'drop type topo_update.input_meta_info cascade;' >> /tmp/trein.sql 
 
 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_01_rls_role_mapping.sql  >> /tmp/trein.sql 

cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_avtaleomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_ekspropriasjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_konsesjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_konvensjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reinbeitedistrikt.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reinbeiteomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_restriksjonsomrade_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_restriksjonsomrade_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_siidaomrade.sql >> /tmp/trein.sql

stop here
################################################################
start here

echo 'drop function if exists org_rein_sosi_dump.date2001_01_01_if_null(date) cascade;' > /tmp/trein.sql
echo 'drop function if exists org_rein_sosi_dump.get_kvalitet_value(character varying,integer);' >> /tmp/trein.sql 
echo 'drop function if exists org_rein_sosi_dump.allebeitebrukerids(character varying,character varying,character varying) cascade;' >> /tmp/trein.sql 
echo 'drop function if exists topo_update.create_nocutline_edge_domain_obj(text,text,text,text,double precision,text) cascade;' >> /tmp/trein.sql 
echo 'drop function if exists  org_rein_sosi_dump.simplefeature_2_topo_surface(text,text,text,text,text,text,text,double precision,geometry) cascade;' >> /tmp/trein.sql 
echo 'drop type topo_update.json_input_structure cascade;' >> /tmp/trein.sql 
echo 'drop type topo_update.input_meta_info cascade;' >> /tmp/trein.sql 

cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/schema_userdef_structures_02.sql >> /tmp/trein.sql
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/function* >> /tmp/trein.sql


cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/import_script/func*.sql >> /tmp/trein.sql 


cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/view*.sql >> /tmp/trein.sql

cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/set_rls_rules.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/set_trigger_update_change_log.sql >> /tmp/trein.sql

cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/roles_tables.sql  >> /tmp/trein.sql 


cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/roles_topo_update.sql >> /tmp/trein.sql



