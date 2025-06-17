-- models/staging/stg_osm_relations.sql
{{ config(materialized='table') }}

SELECT 
    id as relation_id,
    tags,
    refs as member_refs,
    ref_roles AS member_roles,
    ref_types AS member_types,
    CURRENT_TIMESTAMP as processed_at
FROM ST_ReadOSM('{{ var("osm_pbf_path") }}')
WHERE kind = 'relation'
  AND refs IS NOT NULL