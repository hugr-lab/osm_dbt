.PHONY: help install setup download build test docs clean stats hugr-schema

# Load environment variables
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values
REGION ?= $(OSM_REGION_NAME)
TARGET ?= $(DBT_TARGET)
HUGR_PORT ?= 18000

# Default target
help:
	@echo "OSM Universal dbt Project"
	@echo "========================="
	@echo ""
	@echo "Available targets:"
	@echo "  install              - Install Python dependencies"
	@echo "  setup               - Full project setup"
	@echo ""
	@echo "Data Management:"
	@echo "  list-regions        - List available predefined regions" 
	@echo "  download-region     - Download OSM data for region"
	@echo "  process-region      - Process OSM data for region"
	@echo "  quick-region        - Download and process in one step"
	@echo ""
	@echo "dbt Operations:"
	@echo "  build               - Run all dbt models"
	@echo "  build-full          - Run all dbt models (full refresh)"
	@echo "  test                - Run dbt tests"
	@echo "  docs                - Generate and serve dbt docs"
	@echo "  clean               - Clean generated files"
	@echo ""
	@echo "Analysis:"
	@echo "  stats               - Show database statistics"
	@echo "  quality-check       - Run data quality tests"
	@echo ""
	@echo "hugr Integration:"
	@echo "  hugr-schema         - Generate hugr GraphQL schema"
	@echo "  hugr-integration    - Generate hugr data source config"
	@echo ""
	@echo "Variables:"
	@echo "  REGION              - OSM region to process (current: $(REGION))"
	@echo "  TARGET              - dbt target env (current: $(TARGET))"
	@echo "  HUGR_PORT           - hugr server port (current: $(HUGR_PORT))"
	@echo ""
	@echo "Examples:"
	@echo "  make download-region REGION=germany"
	@echo "  make process-region REGION=berlin TARGET=dev"
	@echo "  make quick-region REGION=paris"
	@echo ""

install:
	@echo "📦 Installing dependencies..."
	pip install -r requirements.txt
	@if [ -f "packages.yml" ]; then \
		echo "📦 Installing dbt packages..."; \
		dbt deps; \
	else \
		echo "⚠️  packages.yml not found"; \
	fi

setup: 
	@echo "🚀 Setting up project..."
	bash scripts/setup_project.sh

# Region management
list-regions:
	@echo "📋 Available regions:"
	@sh ./scripts/download_osm_data.sh --list-regions

download-region:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make download-region REGION=germany"; \
		exit 1; \
	fi
	@echo "📥 Downloading OSM data for $(REGION)..."
	@sh ./scripts/download_osm_data.sh --region $(REGION)

process-region:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make process-region REGION=germany"; \
		exit 1; \
	fi
	@echo "🔄 Processing OSM data for $(REGION)..."
	@sh ./scripts/process_region.sh --target $(TARGET) $(REGION)

optimize-db:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make optimize-db REGION=germany"; \
		exit 1; \
	fi
	@echo "⚙️  Optimizing database for $(REGION)..."
	@sh ./scripts/optimize_db.sh --target $(TARGET) $(REGION)

quick-region:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make quick-region REGION=germany"; \
		exit 1; \
	fi
	@echo "🚀 Quick processing $(REGION) (download + process + optimize)..."
	@sh ./scripts/process_region.sh --download --target $(TARGET) $(REGION)
	@sh ./scripts/optimize_db.sh --target $(TARGET) $(REGION)

# dbt operations
build:
	@echo "🏗️  Building all dbt models..."
	dbt run --target $(TARGET)

build-full:
	@echo "🏗️  Building all dbt models (full refresh)..."
	dbt run --target $(TARGET) --full-refresh

test:
	@echo "🧪 Running dbt tests..."
	dbt test --target $(TARGET)

docs:
	@echo "📚 Generating dbt documentation..."
	dbt docs generate --target $(TARGET)
	@echo "🌐 Starting documentation server..."
	dbt docs serve --port 8080

clean:
	@echo "🧹 Cleaning generated files..."
	rm -rf target/
	rm -rf dbt_packages/
	rm -rf logs/
	rm -rf tmp/

clean-data:
	@echo "🧹 Cleaning data files..."
	rm -rf data/processed/*
	rm -rf data/raw/*

# Analysis and statistics
stats:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make stats REGION=germany"; \
		exit 1; \
	fi
	@echo "📊 Database statistics for $(REGION):"
	@dbt run-operation query --target $(TARGET) --args '{sql: "SELECT '\''Points'\'' as type, COUNT(*) as count FROM osm_points UNION ALL SELECT '\''Lines'\'', COUNT(*) FROM osm_lines UNION ALL SELECT '\''Polygons'\'', COUNT(*) FROM osm_polygons UNION ALL SELECT '\''Relations'\'', COUNT(*) FROM osm_relations ORDER BY count DESC"}'

quality-check:
	@echo "🔍 Running data quality checks..."
	@dbt test --target $(TARGET) --select tag:data_quality

# hugr integration
hugr-schema:
	@echo "📝 Generating hugr GraphQL schema files..."
	@echo "Schema files are in models/hugr_schema/"
	@ls -la models/hugr_schema/ 2>/dev/null || echo "⚠️  hugr schema directory not found"

hugr-integration:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make hugr-integration REGION=germany"; \
		exit 1; \
	fi
	@echo "🔗 Generating hugr integration for $(REGION)..."
	@sh ./scripts/hugr_integration.sh --region $(REGION) --target $(TARGET) --port $(HUGR_PORT)

# Development shortcuts
dev-staging:
	@echo "🔄 Running staging models only..."
	dbt run --target $(TARGET) --select staging

dev-intermediate:
	@echo "🔄 Running intermediate models only..."
	dbt run --target $(TARGET) --select intermediate

dev-features:
	@echo "🔄 Running feature models only..."
	dbt run --target $(TARGET) --select marts.features

# Specific feature builds
build-admin:
	@echo "🏛️  Building administrative boundaries..."
	dbt run --target $(TARGET) --select +osm_administrative_boundaries

build-buildings:
	@echo "🏢 Building buildings dataset..."
	dbt run --target $(TARGET) --select +osm_buildings

build-roads:
	@echo "🛣️  Building roads dataset..."
	dbt run --target $(TARGET) --select +osm_roads

build-amenities:
	@echo "🏪 Building amenities dataset..."
	dbt run --target $(TARGET) --select +osm_amenities

build-landuse:
	@echo "🌳 Building landuse dataset..."
	dbt run --target $(TARGET) --select +osm_landuse

# Performance monitoring
profile:
	@echo "📈 Running with profiling enabled..."
	ENABLE_PROFILING=true dbt run --target $(TARGET)
	@echo "Profile saved to tmp/profile.json"

# Multi-region processing
process-europe-cities:
	@echo "🌍 Processing major European cities..."
	@for city in berlin paris london madrid rome; do \
		echo "Processing $$city..."; \
		make quick-region REGION=$$city TARGET=small || true; \
	done

process-us-cities:
	@echo "🇺🇸 Processing major US cities..."
	@for city in california new_york; do \
		echo "Processing $$city..."; \
		make quick-region REGION=$$city TARGET=dev || true; \
	done

# Cleanup operations
clean-logs:
	@echo "🧹 Cleaning log files..."
	rm -rf logs/*

reset-project:
	@echo "🔄 Resetting project to clean state..."
	make clean
	make clean-data
	rm -f .env
	@echo "✅ Project reset. Run 'make setup' to reinitialize."

# Help for specific regions
germany-help:
	@echo "🇩🇪 Germany Processing Guide:"
	@echo "make quick-region REGION=germany TARGET=prod"
	@echo "Expected time: ~30-60 minutes"
	@echo "Memory required: 8-16GB"

berlin-help:
	@echo "🇩🇪 Berlin Processing Guide:"
	@echo "make quick-region REGION=berlin TARGET=dev"
	@echo "Expected time: ~5-10 minutes"
	@echo "Memory required: 2-4GB"

europe-help:
	@echo "🌍 Europe Processing Guide:"
	@echo "make quick-region REGION=europe TARGET=prod"
	@echo "Expected time: 2-4 hours"
	@echo "Memory required: 32-64GB"
	@echo "⚠️  This is a very large dataset!"

# Validation and testing
validate-env:
	@echo "🔍 Validating environment..."
	@if [ -z "$(OSM_REGION_NAME)" ]; then \
		echo "⚠️  OSM_REGION_NAME not set"; \
	else \
		echo "✅ OSM_REGION_NAME: $(OSM_REGION_NAME)"; \
	fi
	@if [ -z "$(OSM_PBF_PATH)" ]; then \
		echo "⚠️  OSM_PBF_PATH not set"; \
	else \
		echo "✅ OSM_PBF_PATH: $(OSM_PBF_PATH)"; \
	fi
	@if [ -f "$(OSM_PBF_PATH)" ]; then \
		echo "✅ OSM file exists: $(shell du -h "$(OSM_PBF_PATH)" | cut -f1)"; \
	else \
		echo "❌ OSM file not found: $(OSM_PBF_PATH)"; \
	fi

check-deps:
	@echo "🔍 Checking dependencies..."
	@python3 --version || echo "❌ Python3 not found"
	@dbt --version || echo "❌ dbt not found"
	@wget --version >/dev/null 2>&1 && echo "✅ wget found" || echo "⚠️  wget not found"
	@curl --version >/dev/null 2>&1 && echo "✅ curl found" || echo "⚠️  curl not found"

# Database operations
db-info:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make db-info REGION=germany"; \
		exit 1; \
	fi
	@DB_PATH="./data/processed/$(REGION)"; \
	if [ "$(TARGET)" = "prod" ]; then \
		DB_PATH="$${DB_PATH}_prod"; \
	elif [ "$(TARGET)" = "small" ]; then \
		DB_PATH="$${DB_PATH}_small"; \
	fi; \
	DB_PATH="$${DB_PATH}.duckdb"; \
	if [ -f "$$DB_PATH" ]; then \
		echo "💾 Database: $$DB_PATH"; \
		echo "📏 Size: $(shell du -h "$$DB_PATH" | cut -f1)"; \
		echo "📅 Modified: $(shell stat -c %y "$$DB_PATH" 2>/dev/null || stat -f %Sm "$$DB_PATH")"; \
	else \
		echo "❌ Database not found: $$DB_PATH"; \
	fi

# Quick development workflows
dev-quick-start:
	@echo "🚀 Quick development start with Berlin..."
	make quick-region REGION=berlin TARGET=dev
	make stats REGION=berlin
	@echo "✅ Development environment ready!"

prod-deploy:
	@if [ -z "$(REGION)" ]; then \
		echo "❌ REGION is required. Use: make prod-deploy REGION=germany"; \
		exit 1; \
	fi
	@echo "🚀 Production deployment for $(REGION)..."
	make quick-region REGION=$(REGION) TARGET=prod
	make test TARGET=prod
	make quality-check TARGET=prod
	make hugr-integration REGION=$(REGION) TARGET=prod
	@echo "✅ Production deployment complete!"
