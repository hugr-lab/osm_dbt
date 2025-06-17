-- models/intermediate/int_complex_multipolygons.sql
{{ config(
    materialized='table',
    pre_hook="SET enable_progress_bar=true"
) }}

WITH multi_relations AS MATERIALIZED (
-- Find all relations with type=multipolygon or boundary
	SELECT 
	    relation_id,
	    tags,
	    tags->>'type' as relation_type,
	    tags->>'name' as name
	FROM {{ ref('stg_osm_relations') }} 
	WHERE tags->>'type' IN ('multipolygon', 'boundary', 'land_area')
	   OR (json_exists(tags, 'landuse') AND NOT json_exists(tags, 'type'))
	   OR (json_exists(tags, 'natural') AND NOT json_exists(tags, 'type'))
	   OR (json_exists(tags, 'building') AND NOT json_exists(tags, 'type'))
	   OR (json_exists(tags, 'administrative') AND NOT json_exists(tags, 'type'))
), relation_way_parts AS MATERIALIZED (
    -- Group ways by roles considering all nested relations
    SELECT 
        mp.relation_id,
        mp.tags,
        mp.relation_type,
        mp.name,
        raw.effective_role,
        -- Determine effective role (outer/inner)
        CASE 
            WHEN raw.effective_role IN ('outer', '') OR raw.effective_role IS NULL THEN 'outer'
            WHEN raw.effective_role = 'inner' THEN 'inner'
            ELSE 'outer'  -- Default to outer
        END as normalized_role,
        ST_Union_Agg(raw.way_geom ORDER BY raw.depth, raw.way_id) as mgeom,
        COUNT(*) as way_count
    FROM multi_relations mp
    	INNER JOIN {{ ref('int_relation_all_ways') }} raw 
        	ON mp.relation_id = raw.parent_relation_id
    WHERE raw.geometry_type = 'linestring' AND
    	ST_IsValid(raw.way_geom) -- Only open ways for building polygons
    GROUP BY mp.relation_id, mp.tags, mp.relation_type, mp.name, raw.effective_role
), assembled_parts AS MATERIALIZED (
    SELECT 
        relation_id,
        tags,
        relation_type,
        name,
        normalized_role,
        mgeom,
        way_count,
        -- Try to assemble rings from ways
        ST_BuildArea(ST_LineMerge(mgeom)) as ring_geom
    FROM relation_way_parts
    WHERE way_count > 0
), rings AS MATERIALIZED (
    SELECT 
        relation_id,
        tags,
        relation_type,
        name,
        -- Collect outer rings
        ARRAY_AGG(
            ring_geom ORDER BY ST_Area(ring_geom) DESC
        ) FILTER (WHERE normalized_role = 'outer' AND ring_geom IS NOT NULL) as outer_rings,
        -- Collect inner rings  
        ARRAY_AGG(
            ring_geom ORDER BY ST_Area(ring_geom) DESC
        ) FILTER (WHERE normalized_role = 'inner' AND ring_geom IS NOT NULL) as inner_rings,
        -- Count statistics
        COUNT(*) FILTER (WHERE normalized_role = 'outer') as outer_count,
        COUNT(*) FILTER (WHERE normalized_role = 'inner') as inner_count
    FROM assembled_parts
    WHERE ring_geom IS NOT NULL AND ST_IsValid(ring_geom)
    GROUP BY relation_id, tags, relation_type, name
), final_polys AS (
    SELECT 
        relation_id,
        tags,
        relation_type,
        name,
        outer_rings,
        inner_rings,
        outer_count,
        inner_count,
        -- Create final geometry
        CASE 
            WHEN LEN(outer_rings) = 1 AND len(inner_rings) = 0 THEN
                -- Simple polygon without holes
                outer_rings[1]
            WHEN LEN(outer_rings) = 1 AND len(inner_rings) > 0 THEN
                -- Polygon with holes
                ST_Difference(outer_rings[1], ST_Collect(inner_rings))
            WHEN LEN(outer_rings) > 1 THEN
                -- Multipolygon
                ST_Collect(
                    ARRAY_TRANSFORM(
                        outer_rings,
                        outer_ring -> CASE 
                            WHEN LEN(inner_rings) > 0 THEN
                                ST_Difference(outer_ring, ST_Collect(inner_rings))
                            ELSE outer_ring
                        END
                    )
                )
            ELSE NULL
        END as final_geom
    FROM rings
    WHERE LEN(outer_rings) > 0
)
SELECT 
    relation_id,
    tags,
    relation_type,
    name,
    outer_rings,
    inner_rings,
    outer_count,
    inner_count,
    final_geom,
    CASE 
        WHEN final_geom IS NOT NULL THEN ST_Area_Spheroid(final_geom)
        ELSE NULL
    END as area_sqm,
    CASE 
        WHEN final_geom IS NOT NULL THEN ST_Perimeter_Spheroid(final_geom)
        ELSE NULL
    END as perimeter_m,
    -- Complexity classification
    CASE 
        WHEN outer_count = 1 AND inner_count = 0 THEN 'simple_polygon'
        WHEN outer_count = 1 AND inner_count > 0 THEN 'polygon_with_holes'
        WHEN outer_count > 1 AND inner_count = 0 THEN 'multipolygon'
        WHEN outer_count > 1 AND inner_count > 0 THEN 'complex_multipolygon'
        ELSE 'unknown'
    END as complexity_type
FROM final_polys
WHERE final_geom IS NOT NULL