PATH := $(PATH):$(shell pg_config --bindir)

POSTGIS_SCRIPT_DIR ?= $(shell find $(shell pg_config --sharedir)/contrib/postgis-* -maxdepth 0 -type d | sort -n | tail -1)

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
#	find / -name shp2pgsql 2>/dev/null # debug 
#	ls # debug
	
	@which shp2pgsql pgsql2shp > /dev/null || \
    { echo "shp2pgsql and pgsql2shp must be in your PATH (which is $${PATH})" && exit 1; }; \
	mkdir -p ../loader; \
	ln -fs `which shp2pgsql` ../loader; \
	ln -fs `which pgsql2shp` ../loader

