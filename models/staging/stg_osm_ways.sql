-- models/staging/stg_osm_ways.sql
{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_way_id ON {{ this }} USING ART (way_id)"
    ]
) }}

SELECT 
    id as way_id,
    tags,
    refs as node_refs,
    CURRENT_TIMESTAMP as processed_at
FROM ST_ReadOSM('{{ var("osm_pbf_path") }}')
WHERE kind = 'way'
  AND refs IS NOT NULL
  AND LEN(refs) >= 2