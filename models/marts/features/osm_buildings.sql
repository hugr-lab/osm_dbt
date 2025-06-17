-- models/marts/features/osm_buildings.sql
{{ config(materialized='table') }}

-- Simple buildings from ways
SELECT 
    way_id as osm_id,
    'way' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'building' as building_type,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags->>'height' as height,
    tags->>'building:levels' as levels,
    tags->>'roof:material' as roof_material,
    tags->>'construction' as construction_status,
    tags->>'amenity' as amenity,
    ST_Area(geom) as area_sqm,
    ST_Perimeter(geom) as perimeter_m,
    'simple' as complexity,
    {{ classify_building("tags->>'building'") }} as building_class,
    tags
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'polygon'
  AND json_exists(tags, 'building')
  AND (tags->>'building') != 'no'

UNION ALL

-- Complex buildings from multipolygon relations
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    final_geom as geom,
    tags->>'name' as name,
    tags->>'building' as building_type,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags->>'height' as height,
    tags->>'building:levels' as levels,
    tags->>'roof:material' as roof_material,
    tags->>'construction' as construction_status,
    tags->>'amenity' as amenity,
    area_sqm,
    perimeter_m,
    complexity_type as complexity,
    {{ classify_building("tags->>'building'") }} as building_class,
    tags
FROM {{ ref('int_complex_multipolygons') }}
WHERE json_exists(tags, 'building')
  AND (tags->>'building') != 'no'
  AND final_geom IS NOT NULL