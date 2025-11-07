.PHONY: help local-up local-down local-logs local-test build-image push-image setup-gke verify-deployment clean

help:
	@echo "Apache Airflow 2.9.1 on GKE - Available Commands"
	@echo ""
	@echo "Local Development:"
	@echo "  make local-test       - Start and test local Airflow with Docker Compose"
	@echo "  make local-up         - Start local Airflow services"
	@echo "  make local-down       - Stop local Airflow services"
	@echo "  make local-logs       - View logs from local services"
	@echo "  make local-clean      - Stop and remove all local containers and volumes"
	@echo ""
	@echo "GKE Deployment:"
	@echo "  make setup-gke        - Setup GKE environment (SA, IAM, secrets)"
	@echo "  make build-image      - Build custom Airflow Docker image"
	@echo "  make push-image       - Build and push image to GCR"
	@echo "  make verify-deployment - Verify GKE deployment"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean            - Clean local environment"
	@echo ""

# Local Development Commands
local-up:
	@echo "Starting local Airflow..."
	docker-compose up -d
	@echo "Waiting for services to start..."
	@sleep 10
	@echo "Services started. Access UI at http://localhost:8080"

local-down:
	@echo "Stopping local Airflow..."
	docker-compose down

local-logs:
	docker-compose logs -f

local-test:
	@./scripts/test-local.sh

local-clean:
	@echo "Cleaning local environment..."
	docker-compose down -v
	@echo "Cleaned!"

# GKE Commands
setup-gke:
	@echo "Setting up GKE environment..."
	@./scripts/setup-gke.sh

build-image:
	@echo "Building Docker image..."
	cd docker && docker build -t airflow-custom:latest .

push-image:
	@echo "Building and pushing image to GCR..."
	@./scripts/build-and-push.sh

verify-deployment:
	@echo "Verifying GKE deployment..."
	@./scripts/verify-deployment.sh

# Cleanup
clean: local-clean
	@echo "Cleaning build artifacts..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Clean complete!"
