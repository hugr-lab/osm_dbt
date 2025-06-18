-- models/marts/core/osm_lines.sql
{{ config(materialized='table') }}

SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'highway' as highway_type,
    tags->>'railway' as railway_type,
    tags->>'waterway' as waterway_type,
    tags->>'power' as power_type,
    tags->>'natural' as natural_type,
    tags->>'barrier' as barrier_type,
    tags->>'surface' as surface,
    tags->>'maxspeed' as max_speed,
    tags->>'lanes' as lanes,
    tags->>'oneway' as oneway,
    tags->>'access' as access,
    tags->>'bridge' as bridge,
    tags->>'tunnel' as tunnel,
    ST_Length(geom) as length_m,
    tags::JSON AS tags,
    processed_at
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'linestring' AND NOT ST_IsEmpty(geom)
  AND tags IS NOT NULL
  AND tags != '{}'::JSON