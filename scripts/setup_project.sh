#!/bin/bash
# scripts/setup_project.sh
# Universal project setup script

set -e

echo "=== OSM Universal dbt Project Setup ==="

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 is required but not installed."
    echo "Please install Python 3.8+ and try again."
    exit 1
fi

echo "✅ Python3 found: $(python3 --version)"

# Check and install DuckDB CLI
echo "🦆 Checking DuckDB CLI..."
if ! command -v duckdb &> /dev/null; then
    echo "📦 Installing DuckDB CLI..."
    curl https://install.duckdb.org | sh
    
    # Add to PATH for current session and future sessions
    export PATH="$HOME/.duckdb/cli/latest:$PATH"
    
    # Add to shell profile for persistence
    if [ -f ~/.zshrc ]; then
        echo 'export PATH="$HOME/.duckdb/cli/latest:$PATH"' >> ~/.zshrc
    elif [ -f ~/.bashrc ]; then
        echo 'export PATH="$HOME/.duckdb/cli/latest:$PATH"' >> ~/.bashrc
    fi
    
    echo "✅ DuckDB CLI installed and added to PATH"
    echo "   You may need to restart your shell or run: source ~/.zshrc"
else
    echo "✅ DuckDB CLI already available"
fi

# Check that we're in the correct directory
if [ ! -f "dbt_project.yml" ]; then
    echo "❌ dbt_project.yml not found. Are you in the project root directory?"
    exit 1
fi

# Create virtual environment
if [ ! -d "venv" ]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
    echo "✅ Virtual environment created"
else
    echo "✅ Virtual environment already exists"
fi

# Activate virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate

# Update pip
echo "📦 Updating pip..."
pip install --upgrade pip --quiet

# Install dependencies
echo "📦 Installing Python dependencies..."
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "✅ Dependencies installed"
else
    echo "❌ requirements.txt not found"
    exit 1
fi

# Check dbt
echo "🔍 Checking dbt installation..."
if dbt --version; then
    echo "✅ dbt is working"
else
    echo "❌ dbt installation failed"
    exit 1
fi

# Create necessary directories
echo "📁 Creating project directories..."
mkdir -p data/raw data/processed tmp logs target

# Copy .env.example to .env if .env doesn't exist
if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ Please edit .env file with your configuration"
fi

# Install dbt dependencies if packages.yml exists
if [ -f "packages.yml" ]; then
    echo "📦 Installing dbt packages..."
    dbt deps
    if [ $? -eq 0 ]; then
        echo "✅ dbt packages installed successfully"
    else
        echo "❌ Failed to install dbt packages"
        echo "Please check packages.yml and try again"
        exit 1
    fi
else
    echo "⚠️  packages.yml not found - some dbt utilities may not be available"
fi

# Check for necessary configuration files
echo "🔍 Checking configuration files..."

if [ ! -f "config/regions.yml" ]; then
    echo "⚠️  config/regions.yml not found - some features may not work"
fi

if [ ! -f "profiles.yml" ]; then
    echo "⚠️  profiles.yml not found - please ensure it exists"
fi

echo ""
echo "✅ Project setup completed successfully!"
echo ""
echo "🚀 Next steps:"
echo "1. Edit .env file with your configuration"
echo "2. Download OSM data:"
echo "   make download-region REGION=germany"
echo "   # or"
echo "   ./scripts/download_osm_data.sh --region germany"
echo ""
echo "3. Process the data:"
echo "   make process-region REGION=germany"
echo "   # or"
echo "   ./scripts/process_region.sh --download germany"
echo ""
echo "4. Check results:"
echo "   make stats"
echo ""
echo "5. Generate hugr schema:"
echo "   make hugr-schema"
echo ""
echo "📚 Available regions:"
echo "   Run: ./scripts/download_osm_data.sh --list-regions"
echo ""
echo "🎯 Quick start with Berlin (small dataset):"
echo "   ./scripts/process_region.sh --download berlin"