-- models/marts/features/osm_roads.sql
{{ config(materialized='table') }}

SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'highway' as road_type,
    tags->>'surface' as surface,
    tags->>'maxspeed' as max_speed,
    tags->>'lanes' as lanes,
    tags->>'oneway' as oneway,
    tags->>'access' as access,
    tags->>'bridge' as bridge,
    tags->>'tunnel' as tunnel,
    tags->>'toll' as toll,
    tags->>'ref' as reference,
    tags->>'operator' as operator,
    tags->>'cycleway' as cycleway,
    tags->>'sidewalk' as sidewalk,
    tags->>'lit' as lit,
    tags->>'width' as width,
    ST_Length(geom) as length_m,
    -- Road classification
    {{ classify_highway("tags->>'highway'") }} as road_class,
    -- Speed limit as integer
    {{ safe_numeric_tag('maxspeed') }} as max_speed_kmh,
    -- Lane count as integer
    TRY_CAST(tags->>'lanes' AS INTEGER) as lane_count,
    tags
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'linestring'
  AND json_exists(tags, 'highway')
  AND (tags->>'highway') NOT IN ('bus_stop', 'crossing', 'give_way', 'stop', 'traffic_signals')