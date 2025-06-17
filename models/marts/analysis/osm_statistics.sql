-- models/marts/analysis/osm_statistics.sql
{{ config(materialized='table') }}

WITH base_counts AS (
    SELECT 
        'nodes' as object_type,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE tags IS NOT NULL AND tags != '{}'::JSON) as tagged_count
    FROM {{ ref('stg_osm_nodes') }}
    
    UNION ALL
    
    SELECT 
        'ways' as object_type,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE tags IS NOT NULL AND tags != '{}'::JSON) as tagged_count
    FROM {{ ref('stg_osm_ways') }}
    
    UNION ALL
    
    SELECT 
        'relations' as object_type,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE tags IS NOT NULL AND tags != '{}'::JSON) as tagged_count
    FROM {{ ref('stg_osm_relations') }}
),
geometry_counts AS (
    SELECT 
        'points' as geometry_type,
        COUNT(*) as count
    FROM {{ ref('osm_points') }}
    
    UNION ALL
    
    SELECT 
        'lines' as geometry_type,
        COUNT(*) as count
    FROM {{ ref('osm_lines') }}
    
    UNION ALL
    
    SELECT 
        'polygons' as geometry_type,
        COUNT(*) as count
    FROM {{ ref('osm_polygons') }}
),
feature_counts AS (
    SELECT 
        'buildings' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_buildings') }}
    
    UNION ALL
    
    SELECT 
        'roads' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_roads') }}
    
    UNION ALL
    
    SELECT 
        'amenities' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_amenities') }}
    
    UNION ALL
    
    SELECT 
        'landuse' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_landuse') }}
    
    UNION ALL
    
    SELECT 
        'water_bodies' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_water_bodies') }}
    
    UNION ALL
    
    SELECT 
        'administrative_boundaries' as feature_type,
        COUNT(*) as count
    FROM {{ ref('osm_administrative_boundaries') }}
),
tag_statistics AS (
    FROM (
        SELECT 
            'most_common_amenities' as statistic_type,
            amenity_type as value,
            COUNT(*) as count
        FROM {{ ref('osm_amenities') }}
        WHERE amenity_type IS NOT NULL
        GROUP BY amenity_type
        ORDER BY COUNT(*) DESC
        LIMIT 10
    )
    
    UNION ALL
    
    FROM (
        SELECT 
            'most_common_landuse' as statistic_type,
            landuse_type as value,
            COUNT(*) as count
        FROM {{ ref('osm_landuse') }}
        WHERE landuse_type IS NOT NULL
        GROUP BY landuse_type
        ORDER BY COUNT(*) DESC
        LIMIT 10
    )
    
    UNION ALL
    
    FROM (
        SELECT 
            'most_common_highways' as statistic_type,
            road_type as value,
            COUNT(*) as count
        FROM {{ ref('osm_roads') }}
        WHERE road_type IS NOT NULL
        GROUP BY road_type
        ORDER BY COUNT(*) DESC
        LIMIT 10
    )
),
area_statistics AS (
    SELECT 
        'total_building_area' as statistic_type,
        'sqm' as value,
        ROUND(SUM(area_sqm), 2) as count
    FROM {{ ref('osm_buildings') }}
    WHERE area_sqm IS NOT NULL
    
    UNION ALL
    
    SELECT 
        'total_road_length' as statistic_type,
        'meters' as value,
        ROUND(SUM(length_m), 2) as count
    FROM {{ ref('osm_roads') }}
    WHERE length_m IS NOT NULL
    
    UNION ALL
    
    SELECT 
        'total_landuse_area' as statistic_type,
        'sqm' as value,
        ROUND(SUM(area_sqm), 2) as count
    FROM {{ ref('osm_landuse') }}
    WHERE area_sqm IS NOT NULL
)
SELECT 
    'summary' as category,
    'total_objects' as metric,
    SUM(total_count)::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM base_counts

UNION ALL

SELECT 
    'summary' as category,
    'tagged_objects' as metric,
    SUM(tagged_count)::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM base_counts

UNION ALL

SELECT 
    'base_objects' as category,
    object_type as metric,
    total_count::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM base_counts

UNION ALL

SELECT 
    'geometries' as category,
    geometry_type as metric,
    count::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM geometry_counts

UNION ALL

SELECT 
    'features' as category,
    feature_type as metric,
    count::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM feature_counts

UNION ALL

SELECT 
    'top_tags' as category,
    statistic_type || '_' || value as metric,
    count::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM tag_statistics

UNION ALL

SELECT 
    'area_stats' as category,
    statistic_type as metric,
    count::TEXT as value,
    CURRENT_TIMESTAMP as calculated_at
FROM area_statistics