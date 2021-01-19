BEGIN;

CREATE SCHEMA IF NOT EXISTS topo_update;
\i :regdir/../../../main/sql/topo_update/function_02_json_props_to_pg_cols.sql

CREATE TABLE json_mappings (id INT primary key, lbl TEXT UNIQUE, map json, props json);

INSERT INTO json_mappings(id, lbl, map, props) VALUES
(1, 'simple', '{
  "from_simple": [ "simple" ],
  "from_comp": [ "comp", "item1" ],
  "from_subcomp": [ "comp", "subcomp", "item2" ]
}', '{
  "simple": 1,
  "comp": {
    "item1": "c1",
    "subcomp": {
      "item2": "sc1"
    }
  }
}'),
(2, 'composite', '{
  "from_simple": [ [ "simple1" ], [ "simple2" ] ],
  "from_comp": [ [ "comp", "item1" ], [ "comp", "subcomp", "item2" ] ]
}', '{
  "simple1": "s1",
  "simple2": "s2",
  "comp": {
    "item1": "c1",
    "subcomp": {
      "item2": "sc1"
    }
  }
}'),
(3, 'nulls', '{
  "to_simple_by_path": [ "a" ],
  "to_simple_by_literal": [ null ],
  "to_comp_mixed": [ [ "a" ], [ "b" ], [ null ] ]
}', '{
  "a": null,
  "b": 1
}')
;

SELECT lbl, colnames, colvals FROM (
  SELECT lbl, (topo_update.json_props_to_pg_cols(props, map)).*
  FROM json_mappings
  ORDER BY id
) foo;

ROLLBACK;
