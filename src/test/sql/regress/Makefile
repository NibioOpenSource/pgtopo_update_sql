check: ../loader 00-regress
	POSTGIS_REGRESS_DB=nibio_reg ./run_test.pl --topology $(RUNTESTFLAGS) topo_update 

../loader:
	mkdir -p ../loader
	ln -fs `which shp2pgsql` ../loader
	ln -fs `which pgsql2shp` ../loader

00-regress:
	mkdir -p 00-regress-install/share/contrib
	ln -fs `pg_config --sharedir`/contrib/postgis-2.2 00-regress-install/share/contrib/postgis
