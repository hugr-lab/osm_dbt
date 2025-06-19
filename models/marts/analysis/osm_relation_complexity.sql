-- models/marts/analysis/osm_relation_complexity.sql
{{ config(materialized='table') }}

WITH relation_depth_stats AS (
    SELECT 
        relation_id,
        MAX(depth) as max_depth,
        COUNT(DISTINCT member_id) FILTER (WHERE member_type = 'way') as total_ways,
        COUNT(DISTINCT member_id) FILTER (WHERE member_type = 'node') as total_nodes,
        COUNT(DISTINCT member_id) FILTER (WHERE member_type = 'relation') as total_nested_relations
    FROM {{ ref('int_relation_hierarchy') }}
    GROUP BY relation_id
),
relation_analysis AS (
    SELECT 
        r.relation_id,
        r.tags->>'name' as name,
        r.tags->>'type' as relation_type,
        COALESCE(rds.max_depth, 1) as max_depth,
        COALESCE(rds.total_ways, 0) as total_ways,
        COALESCE(rds.total_nodes, 0) as total_nodes,
        COALESCE(rds.total_nested_relations, 0) as total_nested_relations,
        -- Direct member counts
        COUNT(rm.member_id) as direct_members,
        COUNT(*) FILTER (WHERE rm.member_type = 'way') as direct_ways,
        COUNT(*) FILTER (WHERE rm.member_type = 'node') as direct_nodes,
        COUNT(*) FILTER (WHERE rm.member_type = 'relation') as direct_nested_relations,
        -- Check if geometry was created
        CASE WHEN mp.relation_id IS NOT NULL THEN true ELSE false END as has_geometry,
        mp.complexity_type,
        mp.area_sqm,
        -- Member roles
        STRING_AGG(DISTINCT rm.member_role, ', ' ORDER BY rm.member_role) as member_roles
    FROM {{ ref('stg_osm_relations') }} r
    LEFT JOIN relation_depth_stats rds ON r.relation_id = rds.relation_id
    LEFT JOIN {{ ref('stg_osm_relation_members') }} rm ON r.relation_id = rm.relation_id
    LEFT JOIN {{ ref('int_complex_multipolygons') }} mp ON r.relation_id = mp.relation_id AND NOT ST_IsEmpty(mp.final_geom)
    GROUP BY r.relation_id, r.tags, rds.max_depth, rds.total_ways, rds.total_nodes, 
             rds.total_nested_relations, mp.relation_id, mp.complexity_type, mp.area_sqm
),
complexity_classification AS (
    SELECT 
        *,
        -- Calculate total objects recursively
        total_ways + total_nodes + total_nested_relations as total_recursive_objects,
        -- Complexity classification
        CASE 
            WHEN total_nested_relations = 0 AND direct_ways <= 10 THEN 'simple'
            WHEN total_nested_relations = 0 AND direct_ways <= 100 THEN 'medium'
            WHEN total_nested_relations > 0 AND max_depth <= 2 THEN 'nested_simple'
            WHEN total_nested_relations > 0 AND max_depth <= 5 THEN 'nested_complex'
            WHEN max_depth > 5 OR total_ways > 1000 THEN 'highly_complex'
            ELSE 'complex'
        END as complexity_class,
        -- Processing difficulty
        CASE 
            WHEN relation_type = 'multipolygon' AND has_geometry THEN 'processed'
            WHEN relation_type = 'multipolygon' AND NOT has_geometry THEN 'failed_processing'
            WHEN relation_type IN ('route', 'boundary') THEN 'special_type'
            ELSE 'other_type'
        END as processing_status
    FROM relation_analysis
)
SELECT 
    relation_id as osm_id,
    name,
    relation_type,
    max_depth,
    direct_members,
    direct_ways,
    direct_nodes,
    direct_nested_relations,
    total_ways,
    total_nodes,
    total_nested_relations,
    total_recursive_objects,
    member_roles,
    has_geometry,
    complexity_type,
    complexity_class,
    processing_status,
    area_sqm,
    CURRENT_TIMESTAMP as calculated_at
FROM complexity_classification
ORDER BY total_recursive_objects DESC, max_depth DESC