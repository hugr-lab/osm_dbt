#!/bin/bash
# scripts/process_region.sh
# Process OSM data for a specific region

set -e

# Load environment variables
if [ -f .env ]; then
    echo "📂 Loading environment variables from .env"
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
else
    echo "⚠️  No .env file found"
fi

# Activate virtual environment if it exists
if [ -f "venv/bin/activate" ]; then
    echo "🔄 Activating virtual environment..."
    source venv/bin/activate
    echo "✅ Virtual environment activated"
else
    echo "⚠️  Virtual environment not found. Run 'make setup' first."
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

# Debug information
echo "🔍 Environment check:"
echo "   Current directory: $(pwd)"
echo "   OSM_REGION_NAME: ${OSM_REGION_NAME:-'not set'}"
echo "   OSM_PBF_PATH: ${OSM_PBF_PATH:-'not set'}"
echo "   OSM_DOWNLOAD_URL: ${OSM_DOWNLOAD_URL:-'not set'}"
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
        
        # Reload environment variables after download
        if [ -f .env ]; then
            echo "🔄 Reloading environment variables after download"
            set -a
            source .env
            set +a
        fi
    else
        echo "❌ Download script not found: scripts/download_osm_data.sh"
        exit 1
    fi
    echo ""
fi

# Check data availability
if [ -z "$OSM_PBF_PATH" ] || [ ! -f "$OSM_PBF_PATH" ]; then
    echo "⚠️  OSM_PBF_PATH not set or file not found: $OSM_PBF_PATH"
    echo "🔍 Searching for OSM data file for region: $REGION"
    
    # Load OSM file finder utility if available
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -f "$SCRIPT_DIR/utils/find_osm_file.sh" ]; then
        source "$SCRIPT_DIR/utils/find_osm_file.sh"
        FOUND_FILE=$(find_osm_file "$REGION" "./data/raw")
    else
        # Fallback: simple search
        FOUND_FILE=""
        for pattern in "./data/raw/${REGION}-latest.osm.pbf" "./data/raw/${REGION}.osm.pbf"; do
            if [ -f "$pattern" ]; then
                FOUND_FILE="$pattern"
                break
            fi
        done
        
        # Last resort: find any .osm.pbf file
        if [ -z "$FOUND_FILE" ]; then
            FOUND_FILE=$(find ./data/raw -name "*.osm.pbf" -type f 2>/dev/null | head -1)
        fi
    fi
    
    if [ -n "$FOUND_FILE" ] && [ -f "$FOUND_FILE" ]; then
        export OSM_PBF_PATH="$FOUND_FILE"
        echo "   ✅ Found OSM file: $OSM_PBF_PATH"
        
        # Update .env file if it exists
        if [ -f ".env" ]; then
            # Remove old OSM_PBF_PATH line and add new one
            grep -v "^OSM_PBF_PATH=" .env > .env.tmp && mv .env.tmp .env
            echo "OSM_PBF_PATH=\"$OSM_PBF_PATH\"" >> .env
            echo "   ✅ Updated .env file with OSM_PBF_PATH"
        fi
    else
        echo "   ❌ No OSM data file found for region: $REGION"
        echo ""
        echo "   🔍 Available files in ./data/raw/:"
        if [ -d "./data/raw" ]; then
            find ./data/raw -name "*.osm.pbf" -type f 2>/dev/null | while read file; do
                size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "unknown")
                echo "      $file ($size)"
            done
            
            if [ -z "$(find ./data/raw -name "*.osm.pbf" -type f 2>/dev/null)" ]; then
                echo "      No .osm.pbf files found"
                echo "      Directory contents:"
                ls -la ./data/raw/ | head -10
            fi
        else
            echo "      Directory ./data/raw does not exist"
        fi
        
        echo ""
        echo "   💡 Solutions:"
        echo "   1. Use --download to download data: $0 --download $REGION"
        echo "   2. Manually download and place file in ./data/raw/"
        echo "   3. Set OSM_PBF_PATH environment variable to the correct path"
        exit 1
    fi
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
    
    # Try to run statistics query
    if dbt run-operation query --target "$DBT_TARGET" --args '{sql: "SELECT '\''Points'\'' as type, COUNT(*) as count FROM osm_points UNION ALL SELECT '\''Lines'\'', COUNT(*) FROM osm_lines UNION ALL SELECT '\''Polygons'\'', COUNT(*) FROM osm_polygons UNION ALL SELECT '\''Relations'\'', COUNT(*) FROM osm_relations ORDER BY count DESC"}' 2>/dev/null; then
        echo "   ✅ Statistics completed"
    else
        echo "   ⚠️  Statistics macro not available"
    fi

    echo ""
    echo "🧹 Cleaning up staging and intermediate models..."
    
    # Try to run cleanup
    if dbt run-operation cleanup_staging_and_intermediate --target "$DBT_TARGET" 2>/dev/null; then
        echo "   ✅ Cleanup completed"
    else
        echo "   ⚠️  Cleanup macro not available"
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