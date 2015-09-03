-- create schema for topo_update data, tables, .... 
CREATE SCHEMA topo_update;

-- make comment this schema  
COMMENT ON SCHEMA topo_update IS 'Is a schema for topo_update attributes and ref to topolygy data. Don´t do any direct update on tables in this schema, all changes should be done using stored proc.';

