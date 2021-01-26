-- from http://stackoverflow.com/questions/18209625/how-do-i-modify-fields-inside-the-new-postgresql-json-datatype
-- since we dont have postgres 9.5
CREATE OR REPLACE FUNCTION topo_update.json_object_set_keys(
  "json"          json,
  "keys_to_set"   TEXT[],
  "values_to_set" anyarray
)
  RETURNS json
  LANGUAGE sql
  IMMUTABLE
  STRICT
AS $function$
SELECT concat('{', string_agg(to_json("key") || ':' || "value", ','), '}')::json
  FROM (SELECT *
          FROM json_each("json")
         WHERE "key" <> ALL ("keys_to_set")
         UNION ALL
        SELECT DISTINCT ON ("keys_to_set"["index"])
               "keys_to_set"["index"],
               CASE
                 WHEN "values_to_set"["index"] IS NULL THEN 'null'::json
                 ELSE to_json("values_to_set"["index"])
               END
          FROM generate_subscripts("keys_to_set", 1) AS "keys"("index")
          JOIN generate_subscripts("values_to_set", 1) AS "values"("index")
         USING ("index")) AS "fields"
$function$;

