BEGIN;

CREATE SCHEMA IF NOT EXISTS topo_update;
\i :regdir/../../../main/sql/topo_update/function_02_json_props_to_pg_cols.sql

CREATE TABLE json_mappings (id INT primary key, map json, props json);

INSERT INTO json_mappings(id, map, props) VALUES
(1, '{
  "from_simple": [ "simple" ],
  "from_complex": [ "complex", "item1" ],
  "from_subcomplex": [ "complex", "subcomplex", "item2" ]
}', '{
  "simple": "3000",
  "complex": {
    "item1": "val1",
    "subcomplex": {
      "item2": "val2"
    }
  }
}'),
(2, '{
  "comp_from_simple": [ [ "simple1" ], [ "simple2" ] ],
  "comp_from_comp": [ [ "complex", "item1" ], [ "complex", "subcomplex", "item2" ] ]
}', '{
  "simple1": "s1",
  "simple2": "s2",
  "complex": {
    "item1": "val1",
    "subcomplex": {
      "item2": "val2"
    }
  }
}')
;

SELECT id, colnames, colvals FROM (
  SELECT id, (topo_update.json_props_to_pg_cols(props, map)).*
  FROM json_mappings
) foo
ORDER BY id;

ROLLBACK;
