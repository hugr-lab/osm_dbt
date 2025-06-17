-- models/intermediate/int_relation_all_ways.sql
{{ config(materialized='table') }}

-- Get all ways from relation and all its nested relations
WITH relation_ways AS (
    SELECT DISTINCT
        rh.relation_id as parent_relation_id,
        rh.member_id as way_id,
        rh.member_role,
        rh.depth,
        rh.relation_path,
        -- Get role from the topmost level if not defined at current level
        FIRST_VALUE(rh.member_role) OVER (
            PARTITION BY rh.relation_id, rh.member_id 
            ORDER BY rh.depth ASC
        ) as effective_role
    FROM {{ ref('int_relation_hierarchy') }} rh
    WHERE rh.member_type = 'way'
),
ways_with_geometry AS (
    SELECT 
        rw.*,
        wg.geom as way_geom,
        wg.geometry_type,
        wg.tags as way_tags
    FROM relation_ways rw
        INNER JOIN {{ ref('int_way_geometries') }} wg 
            ON rw.way_id = wg.way_id
)
FROM ways_with_geometry