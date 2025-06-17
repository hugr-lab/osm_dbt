-- models/intermediate/int_relation_hierarchy.sql
{{ config(materialized='table') }}

-- Recursive CTE for processing nested relations
WITH RECURSIVE relation_hierarchy AS (
    -- Base case: direct members
    SELECT 
        relation_id,
        member_type,
        member_id,
        member_role,
        member_order,
        1 as depth,
        ARRAY[relation_id] as relation_path,
        relation_id::TEXT || '->' || member_type || ':' || member_id::TEXT as path_string
    FROM {{ ref('stg_osm_relation_members') }}
    
    UNION ALL
    
    -- Recursive case: members of relations
    SELECT 
        rh.relation_id,
        rm.member_type,
        rm.member_id,
        rm.member_role,
        rm.member_order,
        rh.depth + 1,
        list_append(rh.relation_path, rm.relation_id),
        rh.path_string || '->' || rm.member_type || ':' || rm.member_id::TEXT
    FROM relation_hierarchy rh
        INNER JOIN {{ ref('stg_osm_relation_members') }} rm 
            ON rh.member_id = rm.relation_id 
            AND rh.member_type = 'relation'
    WHERE rh.depth < {{ var("max_relation_depth", 10) }}  -- Prevent infinite recursion
      AND NOT (rm.relation_id = ANY(rh.relation_path))  -- Prevent cycles
)
FROM relation_hierarchy