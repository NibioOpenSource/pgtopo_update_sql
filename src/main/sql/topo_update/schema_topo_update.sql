-- create schema for topo_update data, tables, .... 
CREATE SCHEMA topo_update;

-- make comment this schema  
COMMENT ON SCHEMA topo_update IS 'Is a schema for topo_update attributes and ref to topolygy data. Don´t do any direct update on tables in this schema, all changes should be done using stored proc.';

-- make the scema public
GRANT USAGE ON SCHEMA topo_update to public;


-- craeted to make it possible to return a set of objects from the topo function
-- Todo find a better way to du this 
DROP TABLE IF EXISTS topo_update.topogeometry_def; 
CREATE TABLE topo_update.topogeometry_def(topo topogeometry);
