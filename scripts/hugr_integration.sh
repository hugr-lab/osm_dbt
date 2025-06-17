#!/bin/bash  
# scripts/hugr_integration.sh
# Generate hugr data source configuration

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

show_help() {
    echo "Hugr Integration Helper"
    echo "======================"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --region REGION    Region name"
    echo "  -t, --target TARGET    dbt target (dev/prod/small)"
    echo "  -p, --port PORT        hugr server port (default: 18000)"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --region germany"
    echo "  $0 --region berlin --target dev"
}

# Default values
REGION="${OSM_REGION_NAME}"
TARGET="${DBT_TARGET:-dev}"
HUGR_PORT="18000"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -p|--port)
            HUGR_PORT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "$REGION" ]; then
    echo "❌ Region is required"
    show_help
    exit 1
fi

# Determine database path
DB_PATH="./data/processed/${REGION}"
if [ "$TARGET" = "prod" ]; then
    DB_PATH="${DB_PATH}_prod"
elif [ "$TARGET" = "small" ]; then
    DB_PATH="${DB_PATH}_small"
fi
DB_PATH="${DB_PATH}.duckdb"

# Check database exists
if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database not found: $DB_PATH"
    echo "Please run processing first:"
    echo "  ./scripts/process_region.sh --download $REGION"
    exit 1
fi

echo "=== Hugr Integration for OSM $REGION ==="
echo "Database: $DB_PATH"
echo "Size: $(du -h "$DB_PATH" | cut -f1)"
echo ""

# Generate GraphQL mutation for creating data source
cat > "/tmp/hugr_${REGION}_datasource.graphql" << EOF
# GraphQL mutation to add OSM $REGION data source to hugr
# Usage: Copy this mutation to hugr admin interface at http://localhost:$HUGR_PORT/admin

mutation addOSM${REGION^}DataSource {
  core {
    insert_data_sources(data: {
      name: "osm_${REGION}"
      type: "duckdb"
      path: "$DB_PATH"
      description: "OpenStreetMap data for ${REGION} processed with dbt"
      as_module: true
      read_only: false
      catalogs: [{
        name: "osm_${REGION}_schema"
        type: "uri"
        path: "./models/hugr_schema"
        description: "OSM ${REGION} data schema definitions for hugr"
      }]
    }) {
      name
      type
      path
      description
      catalogs {
        name
        path
        type
      }
    }
  }
}
EOF

echo "✅ Generated hugr data source configuration:"
echo "File: /tmp/hugr_${REGION}_datasource.graphql"
echo ""
echo "📋 GraphQL Mutation:"
echo "===================="
cat "/tmp/hugr_${REGION}_datasource.graphql"
echo ""
echo "🚀 Integration steps:"
echo "1. Start hugr server"
echo "2. Open http://localhost:$HUGR_PORT/admin"
echo "3. Copy and execute the mutation above"
echo "4. Load the data source:"
echo ""
echo "mutation loadOSM${REGION^}DataSource {"
echo "  function {"
echo "    core {"
echo "      load_data_source(name: \"osm_${REGION}\") {"
echo "        success"
echo "        message"
echo "      }"
echo "    }"
echo "  }"
echo "}"
echo ""
echo "5. Test with a query:"
echo ""
echo "query testOSM${REGION^} {"
echo "  osm_${REGION} {"
echo "    osm_points(limit: 10) {"
echo "      osm_id"
echo "      name"
echo "      amenity_type"
echo "    }"
echo "  }"
echo "}"