# OSM Universal dbt Project

Universal dbt project for processing OpenStreetMap data from any region with support for recursive relations, multipolygons, and all OSM object types.

**Important**: This project is experimental and may change significantly. It is designed to be flexible and extensible for various OSM regions.

## 🌟 Features

- ✅ **Universal Region Support** - Process any OSM region via URL or predefined configs
- ✅ **Full Recursive Relations** - Complete support for nested relations with cycle detection
- ✅ **Multipolygon Processing** - Correct handling of complex polygons with holes
- ✅ **Spatial Indexing** - Automatic spatial indexes for all geometric tables
- ✅ **Data Quality Tests** - Built-in validation and geometry checks
- ✅ **hugr Integration** - Ready GraphQL schemas for hugr geospatial API
- ✅ **Performance Profiling** - Built-in performance monitoring
- ✅ **Modular Architecture** - Easy to extend and customize

## 🏗️ Architecture

### Data Pipeline

```md
OSM PBF File → ST_ReadOSM → Staging → Intermediate → Core & Features → hugr
```

### Key Components

- **Staging**: Raw OSM data (nodes, ways, relations)
- **Intermediate**: Geometry processing, relation hierarchy, multipolygons
- **Core**: Basic object types (points, lines, polygons, relations)
- **Features**: Semantic objects (buildings, roads, amenities, landuse)
- **Analysis**: Statistics and data quality metrics

### Generated Tables

- `osm_points` - All point features (nodes with tags)
- `osm_lines` - All linear features (roads, rivers, etc.)
- `osm_polygons` - All area features (buildings, land areas)
- `osm_relations` - All relations with metadata
- `osm_buildings` - Building-specific features
- `osm_roads` - Road network with classification
- `osm_amenities` - Points of interest
- `osm_landuse` - Land use and land cover
- `osm_administrative_boundaries` - Administrative divisions

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- 8GB+ RAM (varies by region size)
- Internet connection for downloads

### Setup

```bash
# Clone repository
git clone <repository> osm_universal_dbt
cd osm_universal_dbt

# Complete setup
make setup

# Quick start with Berlin (small dataset)
make quick-region REGION=berlin

# View results
make stats REGION=berlin
```

### Available Regions

```bash
# List predefined regions
make list-regions

# Some examples:
# Small:  berlin, paris, london
# Medium: bavaria, california  
# Large:  germany, france, italy
# Huge:   europe (requires 32GB+ RAM)
```

## 📋 Usage Examples

### Process Different Regions

#### Quick Processing (Download + Process)

```bash
# Small city (5-10 minutes)
make quick-region REGION=berlin TARGET=dev

# Country (30-60 minutes)  
make quick-region REGION=germany TARGET=prod

# With custom memory settings
DUCKDB_MEMORY_LIMIT=16GB make quick-region REGION=france
```

#### Step-by-Step Processing

```bash
# Download data
make download-region REGION=spain

# Process with specific target
make process-region REGION=spain TARGET=prod

# Optimize db size
make optimize-db REGION=spain TARGET=prod

# Run tests
make test TARGET=prod
```

### Custom Data Sources

#### From Custom URL

```bash
# Download custom region
./scripts/download_osm_data.sh \
  --url "https://download.geofabrik.de/asia/japan-latest.osm.pbf" \
  --name japan

# Process it
./scripts/process_region.sh japan
```

#### Multiple Regions

```bash
# Process European cities
make process-europe-cities

# Custom batch
for region in germany france italy; do
  make quick-region REGION=$region TARGET=prod
done
```

## 🔧 Configuration

### Environment Variables (.env)

```bash
# Region settings
OSM_REGION_NAME="germany"
OSM_DOWNLOAD_URL="https://download.geofabrik.de/europe/germany-latest.osm.pbf"
OSM_PBF_PATH="./data/raw/germany-latest.osm.pbf"

# Performance settings
DUCKDB_MEMORY_LIMIT="8GB"
DUCKDB_THREADS="4"
DBT_TARGET="dev"

# Processing options
MAX_RELATION_DEPTH="10"
ENABLE_COMPLEX_MULTIPOLYGONS="true"
```

### Predefined Regions (config/regions.yml)

```yaml
regions:
  germany:
    name: "germany"
    url: "https://download.geofabrik.de/europe/germany-latest.osm.pbf"
    memory_limit: "64GB"
    threads: 4
  
  berlin:
    name: "berlin" 
    url: "https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf"
    memory_limit: "16GB"
    threads: 4
```

## 🔗 hugr Integration

### Generate hugr Configuration

```bash
# Generate data source configuration
make hugr-integration REGION=germany
```

```graphql
# This creates a GraphQL mutation like:
mutation addOSMGermanyDataSource {
  core {
    insert_data_sources(
      data: {
        name: "osm.germany"
        type: "duckdb"
        prefix: "osm_germany"
        path: "./data/processed/germany.duckdb"
        description: "OpenStreetMap data for germany processed with dbt"
        as_module: true
        read_only: false
      }
    ) {
      name type path
    }
  }
}
```

### Load Data Source in hugr

```graphql
# After adding the data source, load it:
mutation loadOSMGermanyDataSource {
  function {
    core {
      load_data_source(name: "osm.germany") {
        success
        message
      }
    }
  }
}
```

### Query Examples

```graphql
# Get buildings in Berlin
query berlinBuildings {
  osm_germany {
    osm_buildings(
      filter: {city: {eq: "Berlin"}}
      limit: 100
    ) {
      osm_id
      name
      building_type
      area_sqm
    }
  }
}

# Road statistics by type

query roadStats {
  osm_germany {
    osm_roads_bucket_aggregation {
      key{
        road_class
      }
      aggregations {
        _rows_count
        length_m {
          sum
        }
      }
    }
  }
}

# Administrative boundaries with area
query adminBoundaries {
  osm_germany {
    osm_administrative_boundaries(
      filter: {admin_level: {eq: 8}}
      order_by: [{field: "area_sqm", direction: DESC}]
      limit: 20
    ) {
      name
      admin_level_name
      area_sqm
    }
  }
}
```

## 📊 Data Quality & Analysis

### Built-in Statistics

```bash
# Database statistics
make stats REGION=germany

# Data quality checks
make quality-check

# Generate analysis reports
dbt run --select marts.analysis
```

### Quality Metrics

- Geometry validation (valid/invalid geometries)
- Coordinate validation (lat/lon bounds)
- Tag completeness (tagged vs untagged objects)
- Relation complexity analysis
- Cross-reference integrity

### Performance Monitoring

```bash
# Enable profiling
make profile REGION=germany

# View profile results
cat tmp/profile.json
```

## 🛠️ Development

### Project Structure

```md
osm_universal_dbt/
├── models/
│   ├── staging/          # Raw OSM data processing
│   ├── intermediate/     # Geometry & relation processing
│   ├── marts/
│   │   ├── core/        # Basic object types
│   │   ├── features/    # Semantic features
│   │   └── analysis/    # Statistics & quality
│   └── hugr_schema/     # GraphQL schemas for hugr
├── macros/              # dbt macros & helpers
├── scripts/             # Bash scripts
├── config/              # Region configurations
└── data/                # Processed databases
```

### Adding Custom Features

#### Create New Feature Model

```sql
-- models/marts/features/osm_hospitals.sql
{{ config(materialized='table') }}

SELECT 
    osm_id,
    osm_type,
    geom,
    name,
    tags->>'emergency' as emergency_type,
    tags->>'healthcare' as healthcare_type,
    tags->>'beds' as bed_count,
    tags
FROM {{ ref('osm_amenities') }}
WHERE amenity_type = 'hospital'
   OR healthcare_type IS NOT NULL
```

#### Add Custom Macro

```sql
-- macros/custom_helpers.sql
{% macro extract_healthcare_tags() %}
    tags->>'healthcare' as healthcare_type,
    tags->>'healthcare:speciality' as speciality,
    tags->>'emergency' as emergency_services,
    TRY_CAST(tags->>'beds' AS INTEGER) as bed_count
{% endmacro %}
```

### Testing

#### Run Specific Tests

```bash
# All tests
make test

# Quality tests only
dbt test --select tag:data_quality

# Specific model tests
dbt test --select osm_buildings
```

#### Add Custom Tests

```yaml
# models/marts/features/_features__models.yml
models:
  - name: osm_hospitals
    tests:
      - dbt_utils.unique_combination_of_columns:
          combination_of_columns:
            - osm_id
            - osm_type
    columns:
      - name: bed_count
        tests:
          - dbt_utils.accepted_range:
              min_value: 0
              max_value: 10000
```

## 🎯 Performance Guidelines

### Memory Requirements by Region Size

- **Small cities** (Berlin, Paris): 8GB RAM
- **Large cities** (London, NYC): 8-16GB RAM  
- **Small countries** (Netherlands): 16-32GB RAM
- **Large countries** (Germany, France): 32-64GB RAM
- **Continents** (Europe): 96GB+ RAM

### Processing Time Estimates

- **Berlin**: 5-10 minutes
- **Germany**: 30-60 minutes
- **Europe**: 2-4 hours

### Optimization Tips

```bash
# Use appropriate target for region size
TARGET=small   # For cities
TARGET=dev     # For small countries  
TARGET=prod    # For large datasets

# Adjust memory settings
DUCKDB_MEMORY_LIMIT=64GB make quick-region REGION=germany

# Process specific features only
dbt run --select marts.features.osm_buildings

# Disable complex multipolygons for huge datasets
ENABLE_COMPLEX_MULTIPOLYGONS=false make quick-region REGION=europe
```

## 🔍 Troubleshooting

### Common Issues

#### Out of Memory

It can happen when processing large regions or complex multipolygon. Here are some solutions:

```bash
# Increase memory limit
DUCKDB_MEMORY_LIMIT=64GB make quick-region REGION=large_country

# Use smaller target
make quick-region REGION=large_country TARGET=small

# Disable complex processing
ENABLE_COMPLEX_MULTIPOLYGONS=false make quick-region REGION=large_country
```

Also, ensure your system has enough disk space configured to handle tmp duckdb files. You can set following settings in profiles.yml:

```yaml
# ~/.dbt/profiles.yml
osm_universal_dbt:
  target: dev
  outputs:
    dev:
  ....
      settings:
        memory_limit: "{{ env_var('DUCKDB_MEMORY_LIMIT', '64GB') }}"
        threads: "{{ env_var('DUCKDB_THREADS', '4') | int }}"
        max_temp_directory_size: "150GB" 
  ....
```

You can see all available settings in [DuckDB documentation](https://duckdb.org/docs/stable/configuration/overview).

#### Download Failures

```bash
# Force redownload
make download-region REGION=germany FORCE_REDOWNLOAD=true

# Verify checksums
VERIFY_CHECKSUM=true make download-region REGION=germany

# Use different mirror
OSM_DOWNLOAD_URL="https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf" \
make download-region REGION=custom
```

#### dbt Issues

```bash
# Check dbt installation
dbt --version

# Reinstall packages
dbt clean
dbt deps

# Full refresh
make build-full
```

### Debug Commands

```bash
# Validate environment
make validate-env

# Check dependencies
make check-deps

# Database information
make db-info REGION=germany

# View logs
tail -f logs/dbt.log
```

## 📚 Advanced Usage

### Custom SQL Queries

```bash
# Direct database access
duckdb data/processed/germany.duckdb

# Custom dbt operations
dbt run-operation query --args '{sql: "SELECT COUNT(*) FROM osm_buildings WHERE building_type = \"hospital\""}'
```

### Spatial Analysis Examples

```sql
-- Find buildings within 1km of hospitals
SELECT b.*, h.name as nearest_hospital
FROM osm_buildings b
JOIN osm_amenities h ON h.amenity_type = 'hospital'
WHERE ST_DWithin(b.geom, h.geom, 1000)

-- Road density by administrative area
SELECT 
    a.name,
    SUM(ST_Length_Spheroid(r.geom)) / ST_Area_Spheroid(a.geom) * 1000000 as road_density_per_km2
FROM osm_administrative_boundaries a
JOIN osm_roads r ON ST_Intersects(a.geom, r.geom)
GROUP BY a.name, a.geom
ORDER BY road_density_per_km2 DESC
```

### Automation Scripts

```bash
# Daily processing pipeline
#!/bin/bash
make download-region REGION=germany FORCE_REDOWNLOAD=true
make process-region REGION=germany TARGET=prod
make test TARGET=prod
make hugr-integration REGION=germany TARGET=prod
```

## 🤝 Contributing

### Adding New Regions

1. Add region to `config/regions.yml`
2. Test with `make quick-region REGION=new_region`
3. Document memory requirements
4. Submit PR

### Adding New Features

1. Create model in appropriate marts folder
2. Add tests in YAML file
3. Update documentation
4. Test with multiple regions

### Code Style

- Use English comments and documentation
- Follow dbt naming conventions
- Add appropriate tests
- Document macros and complex logic

## 📝 License

MIT License - see LICENSE file for details.

## 🙏 Acknowledgments

- [OpenStreetMap](https://www.openstreetmap.org/) for the amazing geographic data
- [DuckDB](https://duckdb.org/) for the powerful spatial engine
- [dbt](https://www.getdbt.com/) for the data transformation framework
- [Geofabrik](https://download.geofabrik.de/) for OSM extracts
- [hugr](https://hugr-lab.github.io/) for the GraphQL API platform

----

**Happy mapping! 🗺️**
