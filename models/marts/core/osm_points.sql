-- models/marts/core/osm_points.sql
{{ config(materialized='table') }}

SELECT 
    node_id as osm_id,
    'node' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'amenity' as amenity_type,
    tags->>'shop' as shop_type,
    tags->>'tourism' as tourism_type,
    tags->>'highway' as highway_type,
    tags->>'natural' as natural_type,
    tags->>'place' as place_type,
    tags->>'historic' as historic_type,
    tags->>'cuisine' as cuisine,
    tags->>'opening_hours' as opening_hours,
    tags->>'phone' as phone,
    tags->>'website' as website,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags::JSON AS tags,
    processed_at
FROM {{ ref('stg_osm_nodes') }}
WHERE tags IS NOT NULL
  AND tags != '{}'::JSON