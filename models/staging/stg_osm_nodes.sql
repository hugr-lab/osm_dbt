-- models/staging/stg_osm_nodes.sql
{{ config(materialized='table') }}

{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_node_id ON {{ this }} USING ART (node_id)"
    ]
) }}

SELECT 
    id as node_id,
    lat as latitude,
    lon as longitude,
    ST_Point(lon, lat) as geom,
    tags,
    CURRENT_TIMESTAMP as processed_at
FROM ST_ReadOSM('{{ var("osm_pbf_path") }}')
WHERE kind = 'node'
  AND lat IS NOT NULL 
  AND lon IS NOT NULL
  AND lat BETWEEN -90 AND 90
  AND lon BETWEEN -180 AND 180