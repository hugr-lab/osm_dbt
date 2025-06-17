-- models/staging/stg_osm_way_points.sql
{{ config(materialized='table') }}

SELECT
	way_nodes.way_id,
	array_agg({
		order_num: way_nodes.node_order, 
		geom: nodes.geom
	}) AS points
FROM {{ ref('stg_osm_way_nodes') }} AS way_nodes
	INNER JOIN {{ ref('stg_osm_nodes') }} AS nodes 
        ON way_nodes.node_id = nodes.node_id
GROUP BY way_nodes.way_id