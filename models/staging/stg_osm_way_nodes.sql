-- models/staging/stg_osm_way_nodes.sql
{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_way_id ON {{ this }} USING ART (way_id)"
    ]
) }}

SELECT
    wn.way_id,
    wn.node_id,
    {
		order_num: wn.node_order, 
		geom: nodes.geom
	} AS point
FROM {{ ref('stg_osm_way_pre_nodes') }} wn
    INNER JOIN {{ ref('stg_osm_nodes') }} AS nodes 
        ON wn.node_id = nodes.node_id
