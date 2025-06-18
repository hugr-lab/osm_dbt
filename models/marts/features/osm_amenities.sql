-- models/marts/features/osm_amenities.sql
{{ config(materialized='table') }}

-- POI from nodes
SELECT 
    node_id as osm_id,
    'node' as osm_type,
    geom,
    tags->>'name' as name,
    tags->>'amenity' as amenity_type,
    tags->>'shop' as shop_type,
    tags->>'tourism' as tourism_type,
    tags->>'healthcare' as healthcare_type,
    tags->>'cuisine' as cuisine,
    tags->>'opening_hours' as opening_hours,
    tags->>'phone' as phone,
    tags->>'website' as website,
    tags->>'email' as email,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags->>'operator' as operator,
    tags->>'brand' as brand,
    tags->>'wheelchair' as wheelchair_accessible,
    tags->>'internet_access' as internet_access,
    NULL::DOUBLE as area_sqm,
    -- Category classification
    CASE 
        WHEN json_exists(tags, 'amenity') THEN 'amenity'
        WHEN json_exists(tags, 'shop') THEN 'shop'
        WHEN json_exists(tags, 'tourism') THEN 'tourism'
        WHEN json_exists(tags, 'healthcare') THEN 'healthcare'
        ELSE 'other'
    END as category,
    tags::JSON AS tags
FROM {{ ref('stg_osm_nodes') }}
WHERE json_exists(tags, 'amenity') 
   OR json_exists(tags, 'shop') 
   OR json_exists(tags, 'tourism')
   OR json_exists(tags, 'healthcare')
   OR json_exists(tags, 'office')
   OR json_exists(tags, 'craft')

UNION ALL

-- POI from polygons (using centroid for point representation)
SELECT 
    way_id as osm_id,
    'way' as osm_type,
    ST_Centroid(geom) as geom,
    tags->>'name' as name,
    tags->>'amenity' as amenity_type,
    tags->>'shop' as shop_type,
    tags->>'tourism' as tourism_type,
    tags->>'healthcare' as healthcare_type,
    tags->>'cuisine' as cuisine,
    tags->>'opening_hours' as opening_hours,
    tags->>'phone' as phone,
    tags->>'website' as website,
    tags->>'email' as email,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags->>'operator' as operator,
    tags->>'brand' as brand,
    tags->>'wheelchair' as wheelchair_accessible,
    tags->>'internet_access' as internet_access,
    ST_Area(geom) as area_sqm,
    CASE 
        WHEN json_exists(tags, 'amenity') THEN 'amenity'
        WHEN json_exists(tags, 'shop') THEN 'shop'
        WHEN json_exists(tags, 'tourism') THEN 'tourism'
        WHEN json_exists(tags, 'healthcare') THEN 'healthcare'
        ELSE 'other'
    END as category,
    tags::JSON AS tags
FROM {{ ref('int_way_geometries') }}
WHERE geometry_type = 'polygon'
  AND (
      json_exists(tags, 'amenity') OR 
      json_exists(tags, 'shop') OR 
      json_exists(tags, 'tourism') OR
      json_exists(tags, 'healthcare') OR
      json_exists(tags, 'office') OR
      json_exists(tags, 'craft')
  )

UNION ALL

-- POI from multipolygon relations
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    ST_Centroid(final_geom) as geom,
    tags->>'name' as name,
    tags->>'amenity' as amenity_type,
    tags->>'shop' as shop_type,
    tags->>'tourism' as tourism_type,
    tags->>'healthcare' as healthcare_type,
    tags->>'cuisine' as cuisine,
    tags->>'opening_hours' as opening_hours,
    tags->>'phone' as phone,
    tags->>'website' as website,
    tags->>'email' as email,
    tags->>'addr:street' as street,
    tags->>'addr:housenumber' as house_number,
    tags->>'addr:city' as city,
    tags->>'addr:postcode' as postcode,
    tags->>'operator' as operator,
    tags->>'brand' as brand,
    tags->>'wheelchair' as wheelchair_accessible,
    tags->>'internet_access' as internet_access,
    area_sqm,
    CASE 
        WHEN json_exists(tags, 'amenity') THEN 'amenity'
        WHEN json_exists(tags, 'shop') THEN 'shop'
        WHEN json_exists(tags, 'tourism') THEN 'tourism'
        WHEN json_exists(tags, 'healthcare') THEN 'healthcare'
        ELSE 'other'
    END as category,
    tags::JSON AS tags
FROM {{ ref('int_complex_multipolygons') }}
WHERE (
    json_exists(tags, 'amenity') OR 
    json_exists(tags, 'shop') OR 
    json_exists(tags, 'tourism') OR
    json_exists(tags, 'healthcare') OR
    json_exists(tags, 'office') OR
    json_exists(tags, 'craft')
  )
  AND final_geom IS NOT NULL