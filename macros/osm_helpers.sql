-- macros/osm_helpers.sql
-- OSM-specific helper macros for tag extraction, validation, and classification

-- ================================
-- TAG EXTRACTION MACROS
-- ================================

-- Extract multiple OSM tags with proper naming
{% macro extract_osm_tags(tag_list) %}
  {% for tag in tag_list %}
    tags->'{{ tag }}' as {{ tag | replace(':', '_') | replace('-', '_') }}
    {%- if not loop.last -%},{%- endif %}
  {% endfor %}
{% endmacro %}

-- Common OSM tags used across most features
{% macro common_osm_tags() %}
    {{ extract_osm_tags(['name', 'name:en', 'name:de', 'amenity', 'highway', 'landuse', 'building', 'natural', 'shop', 'tourism']) }}
{% endmacro %}

-- Address-related tags
{% macro address_tags() %}
    {{ extract_osm_tags(['addr:street', 'addr:housenumber', 'addr:city', 'addr:postcode', 'addr:country']) }}
{% endmacro %}

-- Contact information tags
{% macro contact_tags() %}
    {{ extract_osm_tags(['phone', 'website', 'email', 'opening_hours', 'contact:phone', 'contact:website', 'contact:email']) }}
{% endmacro %}

-- Transportation-related tags
{% macro transport_tags() %}
    {{ extract_osm_tags(['highway', 'railway', 'public_transport', 'route', 'operator', 'ref', 'network']) }}
{% endmacro %}

-- Accessibility tags
{% macro accessibility_tags() %}
    {{ extract_osm_tags(['wheelchair', 'wheelchair:description', 'blind', 'deaf', 'tactile_paving']) }}
{% endmacro %}

-- ================================
-- NUMERIC TAG EXTRACTION
-- ================================

-- Safely extract numeric values from tags with regex
{% macro safe_numeric_tag(tag_name, default_value=0) %}
    TRY_CAST(
        REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+(?:\.\d+)?)') 
        AS DOUBLE
    ) 
{% endmacro %}

-- Extract integer values
{% macro safe_integer_tag(tag_name, default_value=0) %}
    TRY_CAST(
        REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+)') 
        AS INTEGER
    ) 
{% endmacro %}

-- Extract speed limit as numeric value
{% macro extract_speed_limit(tag_name='maxspeed') %}
    CASE 
        WHEN (tags->>'{{ tag_name }}') = 'none' THEN NULL
        WHEN (tags->>'{{ tag_name }}') = 'unlimited' THEN NULL
        WHEN (tags->>'{{ tag_name }}') LIKE '%mph' THEN 
            TRY_CAST(REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+)') AS INTEGER) * 1.60934
        ELSE 
            TRY_CAST(REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+)') AS INTEGER)
    END
{% endmacro %}

-- Extract height with unit conversion
{% macro extract_height(tag_name='height') %}
    CASE 
        WHEN (tags->>'{{ tag_name }}') LIKE '%ft' OR (tags->>'{{ tag_name }}') LIKE '%feet' THEN 
            TRY_CAST(REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+(?:\.\d+)?)') AS DOUBLE) * 0.3048
        WHEN (tags->>'{{ tag_name }}') LIKE '%m' OR (tags->>'{{ tag_name }}') NOT LIKE '%[a-zA-Z]%' THEN 
            TRY_CAST(REGEXP_EXTRACT(tags->>'{{ tag_name }}', '^(\d+(?:\.\d+)?)') AS DOUBLE)
        ELSE NULL
    END
{% endmacro %}

-- ================================
-- GEOMETRY VALIDATION MACROS
-- ================================

-- Check if a way should be treated as an area/polygon
{% macro is_area_way() %}
    (
        coordinates[1] = coordinates[-1] 
        AND LEN(coordinates) >= 4 
        AND ((tags->>'area')!= 'no')
        AND (
            json_exists(tags, 'landuse') OR 
            json_exists(tags, 'building') OR 
            json_exists(tags, 'natural') OR 
            json_exists(tags, 'amenity') OR
            json_exists(tags, 'leisure') OR
            json_exists(tags, 'place') OR
            json_exists(tags, 'tourism') OR
            (tags->>'area') = 'yes'
        )
    )
{% endmacro %}

-- Validate coordinate ranges
{% macro validate_coordinates(lat_col, lon_col) %}
    {{ lat_col }} BETWEEN -90 AND 90
    AND {{ lon_col }} BETWEEN -180 AND 180
    AND {{ lat_col }} IS NOT NULL
    AND {{ lon_col }} IS NOT NULL
{% endmacro %}

-- Validate tags are present and not empty
{% macro validate_tags(tags_col) %}
    {{ tags_col }} IS NOT NULL 
    AND {{ tags_col }} != '{}'::JSON
{% endmacro %}

-- ================================
-- CLASSIFICATION MACROS
-- ================================

-- Classify highway types into broader categories
{% macro classify_highway(highway_tag) %}
    CASE 
        WHEN ({{ highway_tag }}) IN ('motorway', 'motorway_link') THEN 'highway'
        WHEN ({{ highway_tag }}) IN ('trunk', 'trunk_link') THEN 'trunk'
        WHEN ({{ highway_tag }}) IN ('primary', 'primary_link') THEN 'primary'
        WHEN ({{ highway_tag }}) IN ('secondary', 'secondary_link') THEN 'secondary'
        WHEN ({{ highway_tag }}) IN ('tertiary', 'tertiary_link') THEN 'tertiary'
        WHEN ({{ highway_tag }}) IN ('unclassified', 'residential') THEN 'local'
        WHEN ({{ highway_tag }}) IN ('service', 'track') THEN 'service'
        WHEN ({{ highway_tag }}) IN ('path', 'footway', 'cycleway', 'bridleway', 'steps') THEN 'path'
        WHEN ({{ highway_tag }}) IN ('pedestrian', 'living_street') THEN 'pedestrian'
        ELSE 'other'
    END
{% endmacro %}

-- Classify building types into broader categories
{% macro classify_building(building_tag) %}
    CASE 
        WHEN ({{ building_tag }}) IN ('house', 'detached', 'residential', 'apartments', 'terrace') THEN 'residential'
        WHEN ({{ building_tag }}) IN ('dormitory', 'hotel', 'hostel') THEN 'accommodation'
        WHEN ({{ building_tag }}) IN ('office', 'commercial', 'retail', 'shop', 'mall') THEN 'commercial'
        WHEN ({{ building_tag }}) IN ('industrial', 'warehouse', 'factory', 'manufacture') THEN 'industrial'
        WHEN ({{ building_tag }}) IN ('school', 'university', 'college', 'kindergarten') THEN 'education'
        WHEN ({{ building_tag }}) IN ('hospital', 'clinic', 'pharmacy') THEN 'healthcare'
        WHEN ({{ building_tag }}) IN ('church', 'mosque', 'synagogue', 'temple', 'cathedral') THEN 'religious'
        WHEN ({{ building_tag }}) IN ('government', 'civic', 'public') THEN 'civic'
        WHEN ({{ building_tag }}) IN ('garage', 'garages', 'parking') THEN 'parking'
        WHEN ({{ building_tag }}) IN ('barn', 'farm', 'stable', 'greenhouse') THEN 'agricultural'
        WHEN ({{ building_tag }}) = 'yes' THEN 'generic'
        ELSE 'other'
    END
{% endmacro %}

-- Classify landuse types into broader categories
{% macro classify_landuse(landuse_tag) %}
    CASE 
        WHEN ({{ landuse_tag }}) IN ('residential', 'housing') THEN 'residential'
        WHEN ({{ landuse_tag }}) IN ('commercial', 'retail') THEN 'commercial'
        WHEN ({{ landuse_tag }}) IN ('industrial', 'port', 'railway') THEN 'industrial'
        WHEN ({{ landuse_tag }}) IN ('forest', 'wood') THEN 'forest'
        WHEN ({{ landuse_tag }}) IN ('farmland', 'farmyard', 'orchard', 'vineyard', 'plant_nursery') THEN 'agriculture'
        WHEN ({{ landuse_tag }}) IN ('grass', 'meadow', 'recreation_ground', 'village_green') THEN 'recreation'
        WHEN ({{ landuse_tag }}) IN ('cemetery', 'grave_yard') THEN 'cemetery'
        WHEN ({{ landuse_tag }}) IN ('construction', 'brownfield', 'greenfield') THEN 'development'
        WHEN ({{ landuse_tag }}) IN ('military', 'garages') THEN 'restricted'
        ELSE 'other'
    END
{% endmacro %}

-- Classify amenity types into broader categories
{% macro classify_amenity(amenity_tag) %}
    CASE 
        WHEN ({{ amenity_tag }}) IN ('restaurant', 'cafe', 'fast_food', 'bar', 'pub', 'food_court') THEN 'food_drink'
        WHEN ({{ amenity_tag }}) IN ('school', 'university', 'college', 'kindergarten', 'library') THEN 'education'
        WHEN ({{ amenity_tag }}) IN ('hospital', 'clinic', 'pharmacy', 'dentist', 'doctors') THEN 'healthcare'
        WHEN ({{ amenity_tag }}) IN ('bank', 'atm', 'bureau_de_change') THEN 'financial'
        WHEN ({{ amenity_tag }}) IN ('fuel', 'charging_station', 'car_wash', 'parking') THEN 'automotive'
        WHEN ({{ amenity_tag }}) IN ('police', 'fire_station', 'post_office', 'townhall') THEN 'public_service'
        WHEN ({{ amenity_tag }}) IN ('cinema', 'theatre', 'arts_centre', 'community_centre') THEN 'entertainment'
        WHEN ({{ amenity_tag }}) IN ('place_of_worship', 'grave_yard') THEN 'religious'
        WHEN ({{ amenity_tag }}) IN ('toilets', 'telephone', 'waste_basket', 'bench') THEN 'utilities'
        ELSE 'other'
    END
{% endmacro %}

-- ================================
-- ADMINISTRATIVE LEVEL MACROS
-- ================================

-- Classify administrative levels according to OSM standards
{% macro classify_admin_level(admin_level_tag) %}
    CASE 
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 1 THEN 'Supranational'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 2 THEN 'Country'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 3 THEN 'First-level subdivision'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 4 THEN 'State/Region'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 5 THEN 'Province/District'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 6 THEN 'County/Prefecture'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 7 THEN 'Municipality group'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 8 THEN 'Municipality'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 9 THEN 'District/Borough'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 10 THEN 'Suburb/Quarter'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 11 THEN 'Neighborhood'
        WHEN TRY_CAST({{ admin_level_tag }} AS INTEGER) = 12 THEN 'City block'
        ELSE 'Other'
    END
{% endmacro %}

-- Validate admin level range
{% macro valid_admin_levels() %}
    TRY_CAST({{ admin_level_tag }} AS INTEGER) BETWEEN 1 AND 12
{% endmacro %}

-- ================================
-- RELATION TYPE HELPERS
-- ================================

-- Check if relation is a multipolygon
{% macro is_multipolygon_relation() %}
    (
        tags->>'type' IN ('multipolygon', 'boundary', 'land_area')
        OR (json_exists(tags, 'landuse') AND tags->>'type' IS NULL)
        OR (json_exists(tags, 'natural') AND tags->>'type' IS NULL)
        OR (json_exists(tags, 'building') AND tags->>'type' IS NULL)
        OR (json_exists(tags, 'administrative') AND tags->>'type' IS NULL)
    )
{% endmacro %}

-- Normalize member roles for multipolygons
{% macro normalize_member_role(role_column) %}
    CASE 
        WHEN ({{ role_column }}) IN ('outer', '') OR {{ role_column }} IS NULL THEN 'outer'
        WHEN ({{ role_column }}) = 'inner' THEN 'inner'
        WHEN ({{ role_column }}) = 'exclave' THEN 'outer'
        WHEN ({{ role_column }}) = 'enclave' THEN 'inner'
        ELSE 'outer'  -- Default to outer for unknown roles
    END
{% endmacro %}

-- ================================
-- BOOLEAN TAG HELPERS
-- ================================

-- Convert OSM boolean values to proper booleans
{% macro osm_boolean(tag_name) %}
    CASE 
        WHEN (tags->>'{{ tag_name }}') IN ('yes', 'true', '1') THEN true
        WHEN (tags->>'{{ tag_name }}') IN ('no', 'false', '0') THEN false
        ELSE NULL
    END
{% endmacro %}

-- Check if way is oneway
{% macro is_oneway() %}
    CASE 
        WHEN (tags->>'oneway') IN ('yes', 'true', '1') THEN true
        WHEN (tags->>'oneway') = '-1' THEN true  -- Oneway in reverse direction
        WHEN (tags->>'oneway') IN ('no', 'false', '0') THEN false
        WHEN (tags->>'junction') = 'roundabout' THEN true  -- Roundabouts are oneway
        ELSE false
    END
{% endmacro %}

-- ================================
-- NAME HANDLING MACROS
-- ================================

-- Get the best available name in preference order
{% macro best_name() %}
    COALESCE(
        tags->>'name:en',
        tags->>'name',
        tags->>'name:de',
        tags->>'name:local',
        tags->>'ref',
        tags->>'addr:street'
    )
{% endmacro %}

-- Get all available names as a JSON object
{% macro all_names() %}
    JSON_OBJECT(
        'name', tags->>'name',
        'name_en', tags->>'name:en',
        'name_de', tags->>'name:de',
        'name_local', tags->>'name:local',
        'official_name', tags->>'official_name',
        'alt_name', tags->>'alt_name',
        'old_name', tags->>'old_name'
    )
{% endmacro %}

-- ================================
-- UTILITY MACROS
-- ================================

-- Check if tag exists and has a meaningful value
{% macro has_meaningful_tag(tag_name) %}
    tags ? '{{ tag_name }}' 
    AND tags->>'{{ tag_name }}' IS NOT NULL 
    AND tags->>'{{ tag_name }}' != '' 
    AND tags->>'{{ tag_name }}' != 'no'
{% endmacro %}

-- Generate OSM object URL
{% macro osm_url(osm_type, osm_id) %}
    'https://www.openstreetmap.org/' || 
    CASE 
        WHEN {{ osm_type }} = 'node' THEN 'node'
        WHEN {{ osm_type }} = 'way' THEN 'way'
        WHEN {{ osm_type }} = 'relation' THEN 'relation'
        ELSE {{ osm_type }}
    END || '/' || {{ osm_id }}::TEXT
{% endmacro %}

-- Extract operator hierarchy (operator > brand > network)
{% macro extract_operator() %}
    COALESCE(
        tags->>'operator',
        tags->>'brand',
        tags->>'network',
        tags->>'owner'
    )
{% endmacro %}

-- ================================
-- DATE/TIME HELPERS
-- ================================

-- Parse opening hours into a more structured format
{% macro parse_opening_hours(tag_name='opening_hours') %}
    CASE 
        WHEN tags->>'{{ tag_name }}' = '24/7' THEN 'always_open'
        WHEN tags->>'{{ tag_name }}' LIKE '%-%' THEN 'scheduled'
        WHEN tags->>'{{ tag_name }}' IN ('closed', 'off') THEN 'closed'
        WHEN tags->>'{{ tag_name }}' IS NOT NULL THEN 'complex_schedule'
        ELSE NULL
    END
{% endmacro %}