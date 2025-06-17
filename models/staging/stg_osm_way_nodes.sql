-- models/staging/stg_osm_way_nodes.sql
{{ config(materialized='table') }}

SELECT
    way_id,
    UNNEST(node_refs) AS node_id,
    generate_subscripts(node_refs, 1) AS node_order
FROM {{ ref('stg_osm_ways') }}
