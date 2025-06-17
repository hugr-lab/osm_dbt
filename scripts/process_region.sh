#!/bin/bash
# scripts/process_region.sh
# Process OSM data for a specific region

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

show_help() {
    echo "OSM Region Processor"
    echo "==================="
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS] REGION"
    echo ""
    echo "Options:"
    echo "  -t, --target TARGET    dbt target (dev/prod/small)"
    echo "  -f, --full-refresh     Force full refresh of all models"
    echo "  -s, --select MODELS    Run only specific models"
    echo "  -d, --download         Download data before processing"
    echo "  --force-download       Force re-download even if file exists"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --download germany"
    echo "  $0 --target prod --full-refresh berlin"
    echo "  $0 --select marts.features.osm_buildings france"
}

# Default values
DBT_TARGET="dev"
FULL_REFRESH=""
SELECT_MODELS=""
DOWNLOAD_DATA="false"
FORCE_DOWNLOAD="false"
REGION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            DBT_TARGET="$2"
            shift 2
            ;;
        -f|--full-refresh)
            FULL_REFRESH="--full-refresh"
            shift
            ;;
        -s|--select)
            SELECT_MODELS="--select $2"
            shift 2
            ;;
        -d|--download)
            DOWNLOAD_DATA="true"
            shift
            ;;
        --force-download)
            FORCE_DOWNLOAD="true"
            DOWNLOAD_DATA="true"  # Автоматически включаем download
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$REGION" ]; then
                REGION="$1"
            else
                echo "❌ Unknown option: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$REGION" ]; then
    echo "❌ Region is required"
    show_help
    exit 1
fi

echo "=== OSM Region Processor ==="
echo "Region: $REGION"
echo "Target: $DBT_TARGET"
echo ""

# Download data if needed
if [ "$DOWNLOAD_DATA" = "true" ]; then
    echo "📥 Downloading OSM data for $REGION..."
    DOWNLOAD_ARGS="--region $REGION"
    if [ "$FORCE_DOWNLOAD" = "true" ]; then
        DOWNLOAD_ARGS="$DOWNLOAD_ARGS --force"
    fi
    
    if [ -f "scripts/download_osm_data.sh" ]; then
        bash scripts/download_osm_data.sh $DOWNLOAD_ARGS
        
        if [ $? -ne 0 ]; then
            echo "❌ Failed to download data"
            exit 1
        fi
    else
        echo "❌ Download script not found: scripts/download_osm_data.sh"
        exit 1
    fi
    echo ""
fi

# Check data availability
if [ -z "$OSM_PBF_PATH" ] || [ ! -f "$OSM_PBF_PATH" ]; then
    echo "❌ OSM data file not found: $OSM_PBF_PATH"
    echo "Use --download to download data first"
    exit 1
fi

echo "📊 Processing OSM data..."
echo "Source file: $OSM_PBF_PATH"
echo "File size: $(du -h "$OSM_PBF_PATH" | cut -f1)"
echo ""

# Set environment variables for dbt
export DBT_TARGET="$DBT_TARGET"
export OSM_REGION_NAME="$REGION"

# Create necessary directories
mkdir -p data/processed tmp logs

# Validate dbt project
if [ ! -f "dbt_project.yml" ]; then
    echo "❌ dbt_project.yml not found. Are you in the right directory?"
    exit 1
fi

# Run dbt
echo "🚀 Running dbt models..."
DBT_COMMAND="dbt run --target $DBT_TARGET $FULL_REFRESH $SELECT_MODELS"
echo "Command: $DBT_COMMAND"
echo ""

eval $DBT_COMMAND

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Processing completed successfully!"
    
    # Show statistics
    echo ""
    echo "📈 Database statistics:"
    
    # Проверяем существует ли макрос query
    if dbt ls --resource-type macro --target "$DBT_TARGET" 2>/dev/null | grep -q "query"; then
        dbt run-operation query --target "$DBT_TARGET" --args '{sql: "SELECT '\''Points'\'' as type, COUNT(*) as count FROM osm_points UNION ALL SELECT '\''Lines'\'', COUNT(*) FROM osm_lines UNION ALL SELECT '\''Polygons'\'', COUNT(*) FROM osm_polygons UNION ALL SELECT '\''Relations'\'', COUNT(*) FROM osm_relations ORDER BY count DESC"}'
    else
        echo "⚠️  Statistics macro not found. Please create macros/query.sql"
    fi

    echo ""
    echo "🧹 Cleaning up staging and intermediate models..."
    
    # Проверяем существует ли макрос cleanup
    if dbt ls --resource-type macro --target "$DBT_TARGET" 2>/dev/null | grep -q "cleanup_staging_and_intermediate"; then
        dbt run-operation cleanup_staging_and_intermediate --target "$DBT_TARGET"
    else
        echo "⚠️  Cleanup macro not found. Please create macros/cleanup.sql"
    fi
    
    # Database information
    DB_PATH="./data/processed/${REGION}"
    if [ "$DBT_TARGET" = "prod" ]; then
        DB_PATH="${DB_PATH}_prod"
    elif [ "$DBT_TARGET" = "small" ]; then
        DB_PATH="${DB_PATH}_small"
    fi
    DB_PATH="${DB_PATH}.duckdb"
    
    if [ -f "$DB_PATH" ]; then
        echo ""
        echo "💾 Database info:"
        echo "   Path: $DB_PATH"
        echo "   Size: $(du -h "$DB_PATH" | cut -f1)"
    fi
    
    echo ""
    echo "🎉 Ready for hugr integration!"
    echo "Database path: $DB_PATH"
else
    echo "❌ Processing failed!"
    exit 1
fi