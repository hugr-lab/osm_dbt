-- models/staging/stg_osm_relation_members.sql
{{ config(materialized='table') }}

WITH unnested AS (
    SELECT 
        relation_id,
        tags,
        UNNEST(member_refs) AS member_id,
        generate_subscripts(member_refs, 1) AS member_order,
        UNNEST(member_roles) AS member_role,
        UNNEST(member_types) AS member_type
    FROM {{ ref('stg_osm_relations') }}
    WHERE member_refs IS NOT NULL
)
FROM unnested
WHERE member_id IS NOT NULL
  AND member_type IS NOT NULL
  AND member_role IS NOT NULL