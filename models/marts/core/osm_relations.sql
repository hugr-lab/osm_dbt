-- models/marts/core/osm_relations.sql
{{ config(materialized='table') }}

WITH relation_stats AS (
    SELECT 
        r.relation_id,
        r.tags,
        r.processed_at,
        -- Count direct members
        COUNT(rm.member_id) as member_count,
        COUNT(*) FILTER (WHERE rm.member_type = 'way') as way_count,
        COUNT(*) FILTER (WHERE rm.member_type = 'node') as node_count,
        COUNT(*) FILTER (WHERE rm.member_type = 'relation') as nested_relation_count,
        -- Get member roles
        STRING_AGG(DISTINCT rm.member_role, ', ' ORDER BY rm.member_role) as member_roles,
        -- Check if it's a multipolygon that was processed
        CASE WHEN mp.relation_id IS NOT NULL THEN true ELSE false END as has_geometry
    FROM {{ ref('stg_osm_relations') }} r
    LEFT JOIN {{ ref('stg_osm_relation_members') }} rm 
        ON r.relation_id = rm.relation_id
    LEFT JOIN {{ ref('int_complex_multipolygons') }} mp 
        ON r.relation_id = mp.relation_id
    GROUP BY r.relation_id, r.tags, r.processed_at, mp.relation_id
)
SELECT 
    relation_id as osm_id,
    'relation' as osm_type,
    tags->>'name' as name,
    tags->>'type' as relation_type,
    tags->>'route' as route_type,
    tags->>'boundary' as boundary_type,
    tags->>'admin_level' as admin_level,
    tags->>'ref' as reference,
    tags->>'operator' as operator,
    tags->>'network' as network,
    member_count,
    way_count,
    node_count,
    nested_relation_count,
    member_roles,
    has_geometry,
    CASE 
        WHEN (tags->>'type' = 'multipolygon') THEN 'multipolygon'
        WHEN (tags->>'type' = 'route') THEN 'route'
        WHEN (tags->>'type' = 'boundary') THEN 'boundary'
        WHEN (tags->>'type' = 'restriction') THEN 'restriction'
        WHEN (tags->>'type' = 'site') THEN 'site'
        WHEN (tags->>'type' = 'associatedStreet') THEN 'associated_street'
        ELSE 'other'
    END as category,
    tags,
    processed_at
FROM relation_stats
WHERE tags IS NOT NULL
  AND tags != '{}'::JSON