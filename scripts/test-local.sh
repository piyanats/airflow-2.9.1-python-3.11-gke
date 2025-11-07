#!/bin/bash

# Script to test local Airflow deployment with Docker Compose
set -e

echo "================================================"
echo "Testing Local Airflow with Docker Compose"
echo "================================================"

# Check if Docker is running
echo "1. Checking Docker..."
if docker info &> /dev/null; then
    echo "✅ Docker is running"
else
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi
echo ""

# Check if docker-compose is available
echo "2. Checking docker-compose..."
if command -v docker-compose &> /dev/null; then
    echo "✅ docker-compose is available"
    docker-compose --version
else
    echo "❌ docker-compose is not installed"
    exit 1
fi
echo ""

# Check if .env file exists
echo "3. Checking .env file..."
if [ -f .env ]; then
    echo "✅ .env file exists"
else
    echo "⚠️  .env file not found, creating from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your settings before continuing"
    exit 1
fi
echo ""

# Create required directories
echo "4. Creating required directories..."
mkdir -p ./dags ./logs ./plugins ./config
echo "✅ Directories created"
echo ""

# Start services
echo "5. Starting Airflow services..."
echo "This may take a few minutes on first run..."
docker-compose up -d

echo ""
echo "Waiting for services to be healthy..."
sleep 30

# Check service status
echo ""
echo "6. Checking service status..."
docker-compose ps
echo ""

# Check if webserver is accessible
echo "7. Checking webserver health..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -f http://localhost:8080/health &> /dev/null; then
        echo "✅ Webserver is healthy!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Waiting for webserver... ($RETRY_COUNT/$MAX_RETRIES)"
        sleep 10
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "⚠️  Webserver health check timeout. Check logs with: docker-compose logs webserver"
else
    echo ""
    echo "================================================"
    echo "✅ Local Airflow is ready!"
    echo "================================================"
    echo ""
    echo "Airflow UI: http://localhost:8080"
    echo "Username: admin"
    echo "Password: admin"
    echo ""
    echo "Useful commands:"
    echo "  View logs: docker-compose logs -f"
    echo "  Stop services: docker-compose down"
    echo "  Restart services: docker-compose restart"
    echo "  Access Airflow CLI: docker-compose run airflow-cli bash"
    echo ""
    echo "To test a DAG:"
    echo "  1. Place your DAG file in ./dags/"
    echo "  2. Wait a few seconds for it to appear in the UI"
    echo "  3. Trigger it from the UI or CLI"
    echo "================================================"
fi
