-- models/staging/stg_osm_way_points.sql
{{ config(
    materialized='table',
    post_hook=[
        "CREATE INDEX IF NOT EXISTS idx_{{ this.name }}_way_id ON {{ this }} USING ART (way_id)"
    ]
) }}

SELECT
	wn.way_id,
	array_agg(wn.point) AS points
FROM {{ ref('stg_osm_way_nodes') }} AS wn
GROUP BY wn.way_id