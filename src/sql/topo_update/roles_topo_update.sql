-- this table are not used 
CREATE ROLE topo_update LOGIN
  ENCRYPTED PASSWORD 'md53ffee2a82ccf4f50d0b37e472c79ffbd'
  NOSUPERUSER NOCREATEROLE;

  -- give the user topo_update right to update spatial_ref_sys and update geometry_columns (This is needed to create tables with geometry collums)
GRANT ALL ON spatial_ref_sys, geometry_columns TO GROUP topo_update;

-- this is a role for users who needs to update tables in the sdr_grl schema
CREATE ROLE topo_update_update_role;
-- grant usage on topo_update to topo_update_update_role
GRANT USAGE ON SCHEMA topo_update TO topo_update_update_role;


-- this is a role for tables that should be read by internet applications  
CREATE ROLE topo_update_dmz_read_role;
-- grant usage on topo_update to topo_update_dmz_read_role
GRANT USAGE ON SCHEMA topo_update TO topo_update_dmz_read_role;




