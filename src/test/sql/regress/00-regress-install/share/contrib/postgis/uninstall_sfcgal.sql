-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- 
-- PostGIS - Spatial Types for PostgreSQL 
-- http://postgis.net 
-- 
-- This is free software; you can redistribute and/or modify it under 
-- the terms of the GNU General Public Licence. See the COPYING file. 
-- 
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- 
-- Generated on: Wed Jun 24 20:57:33 2015
--           by: ../utils/create_undef.pl
--         from: sfcgal.sql
-- 
-- Do not edit manually, your changes will be lost.
-- 
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

BEGIN;

-- Drop all views.
-- Drop all tables.
-- Drop all aggregates.
-- Drop all operators classes and families.
-- Drop all operators.
-- Drop all casts.
-- Drop all functions except 0 needed for type definition.
DROP FUNCTION IF EXISTS postgis_sfcgal_version ();
DROP FUNCTION IF EXISTS ST_3DIntersection (geom1 geometry, geom2 geometry);
DROP FUNCTION IF EXISTS ST_Tesselate (geometry);
DROP FUNCTION IF EXISTS ST_3DArea (geometry);
DROP FUNCTION IF EXISTS ST_Extrude (geometry, float8, float8, float8);
DROP FUNCTION IF EXISTS ST_ForceLHR (geometry);
DROP FUNCTION IF EXISTS ST_Orientation (geometry);
DROP FUNCTION IF EXISTS ST_MinkowskiSum (geometry, geometry);
DROP FUNCTION IF EXISTS ST_StraightSkeleton (geometry);
-- Drop all types.
-- Drop all functions needed for types definition.
-- Drop all schemas.

COMMIT;
