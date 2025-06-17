-- models/marts/features/osm_landuse.sql
{{ config(materialized='table') }}

-- Simple landuse from ways
SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'landuse' as landuse_type,
    tags->>'natural' as natural_type,
    tags->>'leisure' as leisure_type,
    tags->>'place' as place_type,
    COALESCE(
        tags->>'landuse', 
        tags->>'natural', 
        tags->>'leisure',
        tags->>'place'
    ) as primary_type,
    tags->>'operator' as operator,
    tags->>'access' as access,
    tags->>'surface' as surface,
    ST_Area(geom) as area_sqm,
    ST_Perimeter(geom) as perimeter_m,
    'simple' as complexity,
    -- Landuse classification
    CASE 
        WHEN json_exists(tags, 'landuse') THEN {{ classify_landuse("tags->>'landuse'") }}
        WHEN json_exists(tags, 'natural') THEN 'natural'
        WHEN json_exists(tags, 'leisure') THEN 'leisure'
        WHEN json_exists(tags, 'place') THEN 'place'
        ELSE 'other'
    END as landuse_class,
    tags
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'polygon'
  AND (
      json_exists(tags, 'landuse') OR 
      json_exists(tags, 'natural') OR 
      json_exists(tags, 'leisure') OR
      json_exists(tags, 'place')
  )

UNION ALL

-- Complex landuse from multipolygon relations
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    final_geom as geom,
    tags->>'name' as name,
    tags->>'landuse' as landuse_type,
    tags->>'natural' as natural_type,
    tags->>'leisure' as leisure_type,
    tags->>'place' as place_type,
    COALESCE(
        tags->>'landuse', 
        tags->>'natural', 
        tags->>'leisure',
        tags->>'place'
    ) as primary_type,
    tags->>'operator' as operator,
    tags->>'access' as access,
    tags->>'surface' as surface,
    area_sqm,
    perimeter_m,
    complexity_type as complexity,
    CASE 
        WHEN json_exists(tags, 'landuse') THEN {{ classify_landuse("tags->>'landuse'") }}
        WHEN json_exists(tags, 'natural') THEN 'natural'
        WHEN json_exists(tags, 'leisure') THEN 'leisure'
        WHEN json_exists(tags, 'place') THEN 'place'
        ELSE 'other'
    END as landuse_class,
    tags
FROM {{ ref('int_complex_multipolygons') }}
WHERE (
    json_exists(tags, 'landuse') OR 
    json_exists(tags, 'natural') OR 
    json_exists(tags, 'leisure') OR
    json_exists(tags, 'place')
  )
  AND final_geom IS NOT NULL