echo 'drop schema topo_rein cascade;' > /tmp/trein.sql
echo 'drop schema topo_update cascade;'  >> /tmp/trein.sql
echo "select topology.droptopology('topo_rein_sysdata');"  >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/schema*.sql  >> /tmp/trein.sql 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/roles_topo_rein.sql  >> /tmp/trein.sql 
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/tables_01_kode_topo_rein.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_var_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_arstidsbeite_sommer_flate.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_reindrift_anlegg_punkt.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/table_02_trekklei_linje.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/view*.sql >> /tmp/trein.sql
cat ~/dev/git/geomatikk/dbsql/src/db/sl/topo_rein/roles_tables.sql  >> /tmp/trein.sql 
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/schema_*  >> /tmp/trein.sql
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/roles_topo_update.sql >> /tmp/trein.sql
cat ~/dev/git/topologi/pgtopo_update_sql/src/main/sql/topo_update/function*  >> /tmp/trein.sql
cat /tmp/trein.sql