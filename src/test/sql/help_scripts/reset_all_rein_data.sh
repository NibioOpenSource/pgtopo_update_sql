echo 'drop schema topo_rein cascade;' > /tmp/trein.sql
echo 'drop schema topo_update cascade;'  >> /tmp/trein.sql

echo "select topology.droptopology('topo_rein_sysdata');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rvr');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rso');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rhs');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rhv');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rvi');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rbh');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rop');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_ran');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rtr');"  >> /tmp/trein.sql

echo "select topology.droptopology('topo_rein_sysdata_rav');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_reo');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rks');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rko');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rdg');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_reb');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rro');"  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata_rsi');"  >> /tmp/trein.sql

# added delete to handle case old schema exit
echo 'drop schema topo_rein_sysdata cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rvr cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rso cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rhs cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rhv cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rvi cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rbh cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rop cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_ran cascade;' >> /tmp/trein.sql 
echo 'drop schema topo_rein_sysdata_rtr cascade;' >> /tmp/trein.sql 

echo 'drop schema topo_rein_sysdata_rav cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_reo cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_rks cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_rko cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_rdg cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_reb cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_rro cascade;' >> /tmp/trein.sql
echo 'drop schema topo_rein_sysdata_rsi cascade;' >> /tmp/trein.sql



cat ~/dev/git/topologi/pgtopo_update_sql/src/test/sql/help_scripts/Performance_Fix_From_Sandro_TopoJSON.sql>> /tmp/trein.sql 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema*.sql  >> /tmp/trein.sql 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_01_rls_role_mapping.sql  >> /tmp/trein.sql 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/tables_01_kode_topo_rein.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_var_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_sommer_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_host_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_hostvinter_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_vinter_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_punkt.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_trekklei_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_beitehage_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_oppsamlingomr_flate.sql >> /tmp/trein.sql

cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_avtaleomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_ekspropriasjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_konsesjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_konvensjonsomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reinbeitedistrikt.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reinbeiteomrade.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_restriksjonsomrade_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_restriksjonsomrade_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_siidaomrade.sql >> /tmp/trein.sql

cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/view*.sql >> /tmp/trein.sql

cat ~/dev/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/set_rls_rules.sql >> /tmp/trein.sql
cat ~/dev/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/set_trigger_update_change_log.sql >> /tmp/trein.sql


cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/roles_tables.sql  >> /tmp/trein.sql 
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/schema_*  >> /tmp/trein.sql
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/roles_topo_update.sql >> /tmp/trein.sql
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/function*  >> /tmp/trein.sql
#cat /Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/import_script/function_simple*.sql  >> /tmp/trein.sql
#cat /Users/lop/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/convert_to_topo/surface/view/*.sql >> /tmp/trein.sql

#echo "INSERT INTO topo_rein.rls_role_mapping(user_logged_in,session_id,edit_all,table_name,column_name,column_value )
#VALUES('topo_rein_crud1','session_id',true,'*','reinbeitebruker_id','ZD');" >> /tmp/trein.sql 



cat /tmp/trein.sql