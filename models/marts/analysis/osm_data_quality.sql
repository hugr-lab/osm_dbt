-- models/marts/analysis/osm_data_quality.sql
{{ config(materialized='table') }}

WITH node_quality AS (
    SELECT 
        'nodes' as object_type,
        COUNT(*) as total_objects,
        COUNT(*) FILTER (WHERE latitude IS NULL OR longitude IS NULL) as missing_coordinates,
        COUNT(*) FILTER (WHERE latitude < -90 OR latitude > 90) as invalid_latitude,
        COUNT(*) FILTER (WHERE longitude < -180 OR longitude > 180) as invalid_longitude,
        COUNT(*) FILTER (WHERE tags IS NULL OR tags = '{}'::JSON) as untagged_objects,
        COUNT(*) FILTER (WHERE tags->>'name' IS NOT NULL AND (tags->>'name') != '') as named_objects,
        0 as invalid_geometry  -- Not applicable for nodes
    FROM {{ ref('stg_osm_nodes') }}
),
way_quality AS (
    SELECT 
        'ways' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,  -- Not applicable for ways
        0 as invalid_latitude,     -- Not applicable for ways
        0 as invalid_longitude,    -- Not applicable for ways
        COUNT(*) FILTER (WHERE tags IS NULL OR tags = '{}'::JSON) as untagged_objects,
        COUNT(*) FILTER (WHERE tags->>'name' IS NOT NULL AND (tags->>'name') != '') as named_objects,
        COUNT(*) FILTER (WHERE node_refs IS NULL OR LEN(node_refs) < 2) as invalid_geometry
    FROM {{ ref('stg_osm_ways') }}
),
relation_quality AS (
    SELECT 
        'relations' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,  -- Not applicable for relations
        0 as invalid_latitude,     -- Not applicable for relations
        0 as invalid_longitude,    -- Not applicable for relations
        COUNT(*) FILTER (WHERE tags IS NULL OR tags = '{}'::JSON) as untagged_objects,
        COUNT(*) FILTER (WHERE tags->>'name' IS NOT NULL AND (tags->>'name') != '') as named_objects,
        COUNT(*) FILTER (WHERE member_refs IS NULL OR LEN(member_refs) = 0) as invalid_geometry
    FROM {{ ref('stg_osm_relations') }}
),
geometry_quality AS (
    SELECT 
        'polygon_geometries' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,  -- Already filtered in source
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_polygons') }}
    
    UNION ALL
    
    SELECT 
        'line_geometries' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,  -- Already filtered in source
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_lines') }}
    
    UNION ALL
    
    SELECT 
        'point_geometries' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,  -- Already filtered in source
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_points') }}
),
feature_quality AS (
    SELECT 
        'buildings' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_buildings') }}
    
    UNION ALL
    
    SELECT 
        'roads' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_roads') }}
    
    UNION ALL
    
    SELECT 
        'amenities' as object_type,
        COUNT(*) as total_objects,
        0 as missing_coordinates,
        0 as invalid_latitude,
        0 as invalid_longitude,
        0 as untagged_objects,
        COUNT(*) FILTER (WHERE name IS NOT NULL AND name != '') as named_objects,
        COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) as invalid_geometry
    FROM {{ ref('osm_amenities') }}
),
all_quality AS (
    SELECT * FROM node_quality
    UNION ALL
    SELECT * FROM way_quality
    UNION ALL
    SELECT * FROM relation_quality
    UNION ALL
    SELECT * FROM geometry_quality
    UNION ALL
    SELECT * FROM feature_quality
)
SELECT 
    object_type,
    total_objects,
    missing_coordinates,
    invalid_latitude,
    invalid_longitude,
    invalid_geometry,
    untagged_objects,
    named_objects,
    -- Calculate quality percentages
    CASE 
        WHEN total_objects > 0 THEN 
            ROUND((total_objects - missing_coordinates - invalid_latitude - invalid_longitude - invalid_geometry)::DOUBLE / total_objects * 100, 2)
        ELSE 0 
    END as geometry_quality_percent,
    CASE 
        WHEN total_objects > 0 THEN 
            ROUND((total_objects - untagged_objects)::DOUBLE / total_objects * 100, 2)
        ELSE 0 
    END as tagged_percent,
    CASE 
        WHEN total_objects > 0 THEN 
            ROUND(named_objects::DOUBLE / total_objects * 100, 2)
        ELSE 0 
    END as named_percent,
    CURRENT_TIMESTAMP as calculated_at
FROM all_quality
ORDER BY total_objects DESC