-- models/marts/features/osm_water_bodies.sql
{{ config(materialized='table') }}

-- Simple water bodies from ways
SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'natural' as water_type,
    tags->>'water' as water_subtype,
    tags->>'wetland' as wetland_type,
    tags->>'intermittent' as intermittent,
    tags->>'seasonal' as seasonal,
    tags->>'salt' as salt_water,
    ST_Area_Spheroid(geom) as area_sqm,
    ST_Perimeter_Spheroid(geom) as perimeter_m,
    'simple' as complexity,
    CASE 
        WHEN tags->>'natural' = 'water' THEN 'water'
        WHEN tags->>'natural' = 'wetland' THEN 'wetland'
        WHEN json_exists(tags, 'waterway') THEN 'waterway'
        ELSE 'other'
    END as water_class,
    tags
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'polygon' AND NOT ST_IsEmpty(geom)
  AND (
      tags->>'natural' IN ('water', 'wetland') OR
      json_exists(tags, 'waterway')
  )

UNION ALL

-- Complex water bodies with islands from multipolygon relations
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    final_geom as geom,
    tags->>'name' as name,
    tags->>'natural' as water_type,
    tags->>'water' as water_subtype,
    tags->>'wetland' as wetland_type,
    tags->>'intermittent' as intermittent,
    tags->>'seasonal' as seasonal,
    tags->>'salt' as salt_water,
    area_sqm,
    perimeter_m,
    complexity_type as complexity,
    CASE 
        WHEN (tags->>'natural') = 'water' THEN 'water'
        WHEN (tags->>'natural') = 'wetland' THEN 'wetland'
        WHEN json_exists(tags, 'waterway') THEN 'waterway'
        ELSE 'other'
    END as water_class,
    tags
FROM {{ ref('int_complex_multipolygons') }}
WHERE (
      (tags->>'natural') IN ('water', 'wetland') OR
      json_exists(tags, 'waterway')
  )
  AND final_geom IS NOT NULL AND NOT ST_IsEmpty(final_geom)