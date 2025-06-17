-- models/marts/core/osm_polygons.sql
{{ config(materialized='table') }}

-- Simple polygons from ways
SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'landuse' as landuse_type,
    tags->>'building' as building_type,
    tags->>'natural' as natural_type,
    tags->>'amenity' as amenity_type,
    tags->>'leisure' as leisure_type,
    tags->>'tourism' as tourism_type,
    tags->>'place' as place_type,
    tags->>'water' as water_type,
    tags->>'wetland' as wetland_type,
    ST_Area(geom) as area_sqm,
    ST_Perimeter(geom) as perimeter_m,
    'simple' as complexity,
    tags,
    processed_at
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'polygon'
  AND tags IS NOT NULL
  AND tags != '{}'::JSON

UNION ALL

-- Complex polygons from multipolygon relations
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    final_geom as geom,
    tags->>'name' as name,
    tags->>'landuse' as landuse_type,
    tags->>'building' as building_type,
    tags->>'natural' as natural_type,
    tags->>'amenity' as amenity_type,
    tags->>'leisure' as leisure_type,
    tags->>'tourism' as tourism_type,
    tags->>'place' as place_type,
    tags->>'water' as water_type,
    tags->>'wetland' as wetland_type,
    area_sqm,
    perimeter_m,
    complexity_type as complexity,
    tags,
    CURRENT_TIMESTAMP as processed_at
FROM {{ ref('int_complex_multipolygons') }}
WHERE final_geom IS NOT NULL
  AND tags IS NOT NULL
  AND tags != '{}'::JSON