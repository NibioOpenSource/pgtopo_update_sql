TESTS := \
  topo_update \
  json_props_to_pg_cols \
  update_features \
  $(END)

check: loader
	POSTGIS_REGRESS_DB=nibio_reg \
  ./run_test.pl \
  --extension \
  --spatial_ref_sys \
  --topology \
  $(RUNTESTFLAGS) \
  $(TESTS)

loader:
	mkdir -p ../loader; \
	ln -fs `which true` ../loader/shp2pgsql; \
	ln -fs `which true` ../loader/pgsql2shp

