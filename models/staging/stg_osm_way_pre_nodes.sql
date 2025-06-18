-- models/staging/stg_osm_way_pre_nodes.sql
{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_node_id ON {{ this }} USING ART (node_id)"    
    ]
) }}

SELECT
    way_id,
    UNNEST(node_refs) AS node_id,
    generate_subscripts(node_refs, 1) AS node_order
FROM {{ ref('stg_osm_ways') }}