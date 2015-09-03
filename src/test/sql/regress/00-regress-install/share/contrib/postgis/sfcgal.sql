---------------------------------------------------------------------------
--
-- PostGIS - SFCGAL functions
-- Copyright 2012-2013 Oslandia <infos@oslandia.com>
--
-- This is free software; you can redistribute and/or modify it under
-- the terms of the GNU General Public Licence. See the COPYING file.
--
---------------------------------------------------------------------------


--
-- New SFCGAL functions (meaning prototype not already provided by GEOS)
--

BEGIN;
-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION postgis_sfcgal_version() RETURNS text
        AS '$libdir/postgis-2.1'
        LANGUAGE 'c' IMMUTABLE;
        
-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_3DIntersection(geom1 geometry, geom2 geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_intersection3D'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;
       
-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_Tesselate(geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_tesselate'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;
       
-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_3DArea(geometry)
       RETURNS FLOAT8
       AS '$libdir/postgis-2.1','sfcgal_area3D'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;

-- Availability: 2.1.0       
CREATE OR REPLACE FUNCTION ST_Extrude(geometry, float8, float8, float8)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_extrude'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;

-- Availability: 2.1.0       
CREATE OR REPLACE FUNCTION ST_ForceLHR(geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_force_lhr'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;
       
-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_Orientation(geometry)
       RETURNS INT4
       AS '$libdir/postgis-2.1','sfcgal_orientation'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;

-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_MinkowskiSum(geometry, geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_minkowski_sum'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;

-- Availability: 2.1.0
CREATE OR REPLACE FUNCTION ST_StraightSkeleton(geometry)
       RETURNS geometry
       AS '$libdir/postgis-2.1','sfcgal_straight_skeleton'
       LANGUAGE 'c' IMMUTABLE STRICT
       COST 100;

COMMIT;

