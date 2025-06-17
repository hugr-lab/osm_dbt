-- models/marts/features/osm_administrative_boundaries.sql
{{ config(materialized='table') }}

WITH admin_boundaries AS (
    SELECT 
        relation_id,
        tags,
        final_geom as geom,
        area_sqm,
        complexity_type,
        tags->>'name' as name,
        tags->>'name:en' as name_en,
        tags->>'name:de' as name_de,
        TRY_CAST(tags->>'admin_level' AS INTEGER) as admin_level,
        tags->>'boundary' as boundary_type,
        tags->>'place' as place_type,
        tags->>'ISO3166-1' as country_code,
        tags->>'ISO3166-2' as region_code,
        tags->>'ref' as reference_code
    FROM {{ ref('int_complex_multipolygons') }}
    WHERE tags->>'boundary' IN ('administrative', 'political')
      AND json_exists(tags, 'admin_level')
      AND TRY_CAST(tags->>'admin_level' AS INTEGER) BETWEEN 2 AND 11
      AND final_geom IS NOT NULL
),
admin_hierarchy AS (
    -- Determine hierarchy of administrative units through spatial intersection
    SELECT 
        a1.relation_id,
        a1.name,
        a1.name_en,
        a1.name_de,
        a1.admin_level,
        a1.geom,
        a1.area_sqm,
        a1.complexity_type,
        a1.country_code,
        a1.region_code,
        a1.reference_code,
        -- Find parent administrative units
        ARRAY_AGG(
            STRUCT_PACK(
                relation_id := a2.relation_id,
                name := a2.name,
                admin_level := a2.admin_level
            ) ORDER BY a2.admin_level ASC
        ) FILTER (
            WHERE a2.admin_level < a1.admin_level 
            AND ST_Contains(a2.geom, ST_Centroid(a1.geom))
        ) as parent_units,
        -- Find child administrative units
        COUNT(a3.relation_id) FILTER (
            WHERE a3.admin_level > a1.admin_level 
            AND ST_Contains(a1.geom, ST_Centroid(a3.geom))
        ) as child_count,
        a1.tags
    FROM admin_boundaries a1
    LEFT JOIN admin_boundaries a2 ON a2.admin_level < a1.admin_level
    LEFT JOIN admin_boundaries a3 ON a3.admin_level > a1.admin_level
    GROUP BY a1.relation_id, a1.name, a1.name_en, a1.name_de, a1.admin_level, 
             a1.geom, a1.area_sqm, a1.complexity_type, a1.country_code, 
             a1.region_code, a1.reference_code, a1.tags
)
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    geom,
    name,
    name_en,
    name_de,
    admin_level,
    {{ classify_admin_level('admin_level') }} as admin_level_name,
    area_sqm,
    complexity_type,
    country_code,
    region_code,
    reference_code,
    parent_units,
    child_count,
    tags
FROM admin_hierarchy
ORDER BY admin_level, area_sqm DESC