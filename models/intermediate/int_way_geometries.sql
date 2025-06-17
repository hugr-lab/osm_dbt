-- models/intermediate/int_way_geometries.sql
{{ config(materialized='table') }}

WITH way_coordinates AS (
    SELECT 
        w.way_id,
        w.tags,
		list_transform(
			list_grade_up(
				list_transform(wp.points, p-> p['order_num'])
			),
			i->wp.points[i]['geom']
		) AS coordinates,
        w.processed_at
	FROM {{ ref('stg_osm_ways') }} w
		INNER JOIN {{ ref('stg_osm_way_points') }} AS wp ON w.way_id = wp.way_id
), way_geometries AS (
    SELECT 
        way_id,
        tags,
        coordinates,
        CASE 
            -- Closed polygon (first and last points match, minimum 4 points)
	        WHEN coordinates[1] = coordinates[-1] 
                 AND LEN(coordinates) >= 4 
                 AND COALESCE(tags->>'area','') != 'no'
                 AND (
                     json_exists(tags, 'landuse') OR
                     json_exists(tags, 'building') OR
                     json_exists(tags, 'building:part') OR
                     json_exists(tags, 'natural') OR
                     json_exists(tags, 'amenity') OR
                     json_exists(tags, 'leisure') OR
                     json_exists(tags, 'place') OR
                     COALESCE(tags->>'area', '') = 'yes'
                 )
            THEN 'polygon'
            -- Otherwise line
            ELSE 'linestring'
        END as geometry_type,
        CASE 
            WHEN geometry_type = 'polygon' THEN ST_MakePolygon(ST_MakeLine(coordinates))
            ELSE ST_MakeLine(coordinates)
        END as geom,
        processed_at
    FROM way_coordinates
    WHERE LEN(coordinates) >= 2
)
FROM way_geometries