#!/bin/bash
# scripts/optimize_database.sh
# Optimize DuckDB database size through copy operation

set -e

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

show_help() {
    echo "DuckDB Database Optimizer"
    echo "========================"
    echo ""
    echo "Usage:"
    echo "  $0 [OPTIONS] REGION"
    echo ""
    echo "Options:"
    echo "  -t, --target TARGET    dbt target (dev/prod/small)"
    echo "  -b, --backup           Create backup before optimization"
    echo "  -v, --verbose          Verbose output"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 bw"
    echo "  $0 --target prod --backup berlin"
    echo "  $0 --verbose germany"
}

# Default values
DBT_TARGET="dev"
CREATE_BACKUP="false"
VERBOSE="false"
REGION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            DBT_TARGET="$2"
            shift 2
            ;;
        -b|--backup)
            CREATE_BACKUP="true"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
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

# Build database path based on region and target
DB_PATH="./data/processed/${REGION}"
if [ "$DBT_TARGET" = "prod" ]; then
    DB_PATH="${DB_PATH}_prod"
elif [ "$DBT_TARGET" = "small" ]; then
    DB_PATH="${DB_PATH}_small"
fi
DB_PATH="${DB_PATH}.duckdb"

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database file not found: $DB_PATH"
    exit 1
fi

echo "🗜️  DuckDB Database Optimizer"
echo "Region: $REGION"
echo "Target: $DBT_TARGET"
echo "Database: $DB_PATH"
echo ""

# Get original size
ORIGINAL_SIZE=$(du -h "$DB_PATH" | cut -f1)

echo "📊 Original database size: $ORIGINAL_SIZE"

# Create backup if requested
if [ "$CREATE_BACKUP" = "true" ]; then
    BACKUP_PATH="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "💾 Creating backup: $BACKUP_PATH"
    cp "$DB_PATH" "$BACKUP_PATH"
    if [ $? -eq 0 ]; then
        echo "   ✅ Backup created successfully"
    else
        echo "   ❌ Failed to create backup"
        exit 1
    fi
fi

# Create temporary paths
DB_PATH_TEMP="${DB_PATH}.temp"
DB_PATH_OPTIMIZED="${DB_PATH}.optimized"

echo "🔄 Starting optimization process..."

# Step 1: Rename original database
if [ "$VERBOSE" = "true" ]; then
    echo "   Renaming original database to temporary file..."
fi

if mv "$DB_PATH" "$DB_PATH_TEMP"; then
    if [ "$VERBOSE" = "true" ]; then
        echo "   ✅ Database renamed successfully"
    fi
else
    echo "❌ Failed to rename database"
    exit 1
fi

# Step 2: Create optimization script
OPTIMIZE_SCRIPT=$(cat << EOF
.timer on
INSTALL spatial;
LOAD spatial;

-- Show original database info
ATTACH '$DB_PATH_TEMP' AS source_db (READ_ONLY);
SELECT 'Original tables count: ' || COUNT(*) FROM source_db.information_schema.tables;

-- Create optimized database
ATTACH '$DB_PATH_OPTIMIZED' AS target_db;

-- Copy all data with optimization
COPY FROM DATABASE source_db TO target_db;

-- Show optimized database info  
SELECT 'Optimized tables count: ' || COUNT(*) FROM target_db.information_schema.tables;

-- Cleanup
DETACH source_db;
DETACH target_db;

.quit
EOF
)

# Step 3: Run optimization
if [ "$VERBOSE" = "true" ]; then
    echo "   Running DuckDB optimization script..."
    echo "$OPTIMIZE_SCRIPT" | duckdb
else
    echo "$OPTIMIZE_SCRIPT" | duckdb > /dev/null 2>&1
fi

# Step 4: Check results and finalize
if [ $? -eq 0 ] && [ -f "$DB_PATH_OPTIMIZED" ]; then
    # Move optimized database to final location
    mv "$DB_PATH_OPTIMIZED" "$DB_PATH"
    
    # Get new size
    NEW_SIZE=$(du -h "$DB_PATH" | cut -f1)
    
    
    echo ""
    echo "✅ Optimization completed successfully!"
    echo "📊 Results:"
    echo "   Original size:  $ORIGINAL_SIZE"
    echo "   Optimized size: $NEW_SIZE"
    
    # Remove temporary file
    rm -f "$DB_PATH_TEMP"
    echo "   Temporary file removed"
    
else
    echo "❌ Optimization failed!"
    echo "🔄 Restoring original database..."
    
    # Remove failed optimization file if it exists
    rm -f "$DB_PATH_OPTIMIZED"
    
    # Restore original database
    mv "$DB_PATH_TEMP" "$DB_PATH"
    echo "   Original database restored"
    exit 1
fi

echo ""
echo "🎉 Database optimization complete!"
echo "Final database: $DB_PATH"
echo ""
echo "💡 hugr data source configuration:"
echo "   Region: $REGION"
echo "   Target: $DBT_TARGET"
echo "   Name: ${REGION}_${DBT_TARGET}"
echo "   Type: duckdb"
echo "   Path: $DB_PATH"