#!/bin/bash
# scripts/download_osm_data.sh
# Universal OSM data downloader

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Functions for working with YAML
parse_yaml() {
    local file="$1"
    local prefix="$2"
    python3 -c "
import yaml
import sys
with open('$file', 'r') as f:
    config = yaml.safe_load(f)
    
if '$prefix' in config:
    for key, value in config['$prefix'].items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                print(f'{key}_{subkey}={subvalue}')
        else:
            print(f'{key}={value}')
"
}

show_help() {
    echo "OSM Universal Data Downloader"
    echo "============================"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -u, --url URL           Direct download URL"
    echo "  -r, --region REGION     Use predefined region from config/regions.yml"
    echo "  -n, --name NAME         Custom region name"
    echo "  -f, --force            Force re-download even if file exists"
    echo "  -c, --checksum         Verify checksum if available"
    echo "  -l, --list-regions     List available predefined regions"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  OSM_DOWNLOAD_URL       Default download URL"
    echo "  OSM_REGION_NAME        Default region name"
    echo "  FORCE_REDOWNLOAD       Force redownload (true/false)"
    echo "  VERIFY_CHECKSUM        Verify checksum (true/false)"
    echo ""
    echo "Examples:"
    echo "  $0 --region germany"
    echo "  $0 --url https://example.com/data.osm.pbf --name my_region"
    echo "  $0 --region berlin --force"
}

list_regions() {
    echo "Available predefined regions:"
    echo "============================"
    if [ -f "config/regions.yml" ]; then
        python3 -c "
import yaml
with open('config/regions.yml', 'r') as f:
    config = yaml.safe_load(f)
    for region, details in config['regions'].items():
        print(f'{region:20} - {details.get(\"description\", \"No description\")}')
"
    else
        echo "❌ config/regions.yml not found"
        exit 1
    fi
}

# Parse arguments
DOWNLOAD_URL=""
REGION_NAME=""
FORCE_DOWNLOAD="false"
VERIFY_CHECKSUM="false"
PREDEFINED_REGION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            DOWNLOAD_URL="$2"
            shift 2
            ;;
        -r|--region)
            PREDEFINED_REGION="$2"
            shift 2
            ;;
        -n|--name)
            REGION_NAME="$2"
            shift 2
            ;;
        -f|--force)
            FORCE_DOWNLOAD="true"
            shift
            ;;
        -c|--checksum)
            VERIFY_CHECKSUM="true"
            shift
            ;;
        -l|--list-regions)
            list_regions
            exit 0
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

# If predefined region is specified, load its settings
if [ -n "$PREDEFINED_REGION" ]; then
    if [ -f "config/regions.yml" ]; then
        echo "Loading configuration for region: $PREDEFINED_REGION"
        
        # Extract region settings
        REGION_CONFIG=$(python3 -c "
import yaml
import sys
with open('config/regions.yml', 'r') as f:
    config = yaml.safe_load(f)
    if '$PREDEFINED_REGION' in config['regions']:
        region = config['regions']['$PREDEFINED_REGION']
        print(f\"url={region['url']}\")
        print(f\"name={region['name']}\")
        print(f\"memory_limit={region.get('memory_limit', '8GB')}\")
        print(f\"threads={region.get('threads', 4)}\")
    else:
        print('ERROR: Region not found', file=sys.stderr)
        sys.exit(1)
")
        
        if [ $? -ne 0 ]; then
            echo "❌ Region '$PREDEFINED_REGION' not found in config/regions.yml"
            echo "Use --list-regions to see available regions"
            exit 1
        fi
        
        # Apply settings
        eval "$REGION_CONFIG"
        DOWNLOAD_URL="$url"
        REGION_NAME="$name"
        
        # Update environment variables for dbt
        export OSM_DOWNLOAD_URL="$DOWNLOAD_URL"
        export OSM_REGION_NAME="$REGION_NAME"
        export DUCKDB_MEMORY_LIMIT="$memory_limit"
        export DUCKDB_THREADS="$threads"
        
        echo "✅ Configuration loaded:"
        echo "   Region: $REGION_NAME"
        echo "   URL: $DOWNLOAD_URL"
        echo "   Memory: $memory_limit"
        echo "   Threads: $threads"
    else
        echo "❌ config/regions.yml not found"
        exit 1
    fi
fi

# Use environment variables as fallback
DOWNLOAD_URL="${DOWNLOAD_URL:-$OSM_DOWNLOAD_URL}"
REGION_NAME="${REGION_NAME:-$OSM_REGION_NAME}"
FORCE_DOWNLOAD="${FORCE_DOWNLOAD:-$FORCE_REDOWNLOAD}"
VERIFY_CHECKSUM="${VERIFY_CHECKSUM:-$VERIFY_CHECKSUM}"

# Check required parameters
if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Download URL is required"
    echo "Use --url, --region, or set OSM_DOWNLOAD_URL environment variable"
    exit 1
fi

if [ -z "$REGION_NAME" ]; then
    echo "❌ Region name is required"
    echo "Use --name, --region, or set OSM_REGION_NAME environment variable"
    exit 1
fi

# Setup paths
DATA_DIR="./data"
RAW_DIR="$DATA_DIR/raw"
OSM_FILENAME="${REGION_NAME}-latest.osm.pbf"
OSM_FILE="$RAW_DIR/$OSM_FILENAME"

echo "=== OSM Universal Data Downloader ==="
echo "Region: $REGION_NAME"
echo "URL: $DOWNLOAD_URL"
echo "Target: $OSM_FILE"
echo ""

# Create directories
mkdir -p "$RAW_DIR"

# Check if file exists
if [ -f "$OSM_FILE" ] && [ "$FORCE_DOWNLOAD" != "true" ]; then
    echo "✅ OSM file already exists: $OSM_FILE"
    echo "File size: $(du -h "$OSM_FILE" | cut -f1)"
    echo "Modified: $(stat -c %y "$OSM_FILE" 2>/dev/null || stat -f %Sm "$OSM_FILE")"
    echo ""
    
    read -p "Do you want to re-download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping download."
        # Update path variable for dbt
        export OSM_PBF_PATH="$OSM_FILE"
        echo "OSM_PBF_PATH=$OSM_FILE"
        exit 0
    fi
fi

echo "📥 Downloading OSM data..."
echo "Source: $DOWNLOAD_URL"
echo "Target: $OSM_FILE"

# Create temporary file
TEMP_FILE="${OSM_FILE}.tmp"

# Download with progress bar and resume support
if command -v wget >/dev/null 2>&1; then
    wget --progress=bar:force:noscroll \
         --continue \
         --timeout=30 \
         --tries=3 \
         -O "$TEMP_FILE" \
         "$DOWNLOAD_URL"
elif command -v curl >/dev/null 2>&1; then
    curl --progress-bar \
         --continue-at - \
         --connect-timeout 30 \
         --retry 3 \
         --output "$TEMP_FILE" \
         "$DOWNLOAD_URL"
else
    echo "❌ Neither wget nor curl found. Please install one of them."
    exit 1
fi

# Check download success
if [ $? -eq 0 ] && [ -f "$TEMP_FILE" ]; then
    # Move from temporary file
    mv "$TEMP_FILE" "$OSM_FILE"
    
    echo "✅ Download completed successfully!"
    echo "File size: $(du -h "$OSM_FILE" | cut -f1)"
    
    # File verification
    if command -v file >/dev/null 2>&1; then
        FILE_TYPE=$(file "$OSM_FILE")
        echo "File type: $FILE_TYPE"
        
        if [[ "$FILE_TYPE" != *"protocol buffer"* ]] && [[ "$FILE_TYPE" != *"data"* ]]; then
            echo "⚠️  Warning: File doesn't appear to be a valid PBF file"
        fi
    fi
    
    # Checksum verification (if available)
    if [ "$VERIFY_CHECKSUM" = "true" ]; then
        CHECKSUM_URL="${DOWNLOAD_URL}.md5"
        echo "🔍 Checking for MD5 checksum..."
        
        if wget -q --spider "$CHECKSUM_URL" 2>/dev/null; then
            echo "📥 Downloading checksum..."
            wget -q -O "${OSM_FILE}.md5" "$CHECKSUM_URL"
            
            if [ -f "${OSM_FILE}.md5" ]; then
                echo "🔍 Verifying checksum..."
                if command -v md5sum >/dev/null 2>&1; then
                    cd "$RAW_DIR"
                    if md5sum -c "${OSM_FILENAME}.md5"; then
                        echo "✅ Checksum verification passed"
                    else
                        echo "❌ Checksum verification failed"
                        exit 1
                    fi
                    cd - >/dev/null
                else
                    echo "⚠️  md5sum not available, skipping verification"
                fi
            fi
        else
            echo "ℹ️  No checksum file available"
        fi
    fi
    
    # Update environment variables
    export OSM_PBF_PATH="$OSM_FILE"
    
    # Create/update .env file
    if [ -f .env ]; then
        # Update existing variables
        sed -i.bak "s|^OSM_PBF_PATH=.*|OSM_PBF_PATH=\"$OSM_FILE\"|" .env
        sed -i.bak "s|^OSM_REGION_NAME=.*|OSM_REGION_NAME=\"$REGION_NAME\"|" .env
        sed -i.bak "s|^OSM_DOWNLOAD_URL=.*|OSM_DOWNLOAD_URL=\"$DOWNLOAD_URL\"|" .env
        rm .env.bak
    else
        # Create new .env file
        cat > .env << EOF
# Generated by download_osm_data.sh
OSM_DOWNLOAD_URL="$DOWNLOAD_URL"
OSM_REGION_NAME="$REGION_NAME"
OSM_PBF_PATH="$OSM_FILE"
DBT_TARGET="dev"
DUCKDB_MEMORY_LIMIT="${DUCKDB_MEMORY_LIMIT:-8GB}"
DUCKDB_THREADS="${DUCKDB_THREADS:-4}"
EOF
    fi
    
    echo ""
    echo "📝 Environment variables updated:"
    echo "   OSM_PBF_PATH=$OSM_FILE"
    echo "   OSM_REGION_NAME=$REGION_NAME"
    echo "   OSM_DOWNLOAD_URL=$DOWNLOAD_URL"
    
else
    echo "❌ Download failed!"
    rm -f "$TEMP_FILE"
    exit 1
fi
