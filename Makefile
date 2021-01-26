INPUT_SQL := \
	$(shell find src/sql/topo_update/ -name 'schema_*' | sort) \
	$(shell find src/sql/topo_update/ -name 'function_*' | sort) \
	$(END)

all: topo_update.sql ## Build schema loader script

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

topo_update.sql: $(INPUT_SQL) Makefile
	echo "BEGIN;" > $@
	cat $(INPUT_SQL) >> $@
	echo "COMMIT;" >> $@

check: topo_update.sql ## Run regression testing
	$(MAKE) -C test/regress/ check
