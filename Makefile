.PHONY: help local-up local-down local-logs local-test build-image push-image setup-gke verify-deployment create-secrets setup-secret-manager test test-dags test-unit test-integration lint format install-test-deps install-hooks clean

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
	@echo "Testing:"
	@echo "  make test             - Run all tests"
	@echo "  make test-dags        - Run DAG validation tests"
	@echo "  make test-unit        - Run unit tests"
	@echo "  make test-integration - Run integration tests"
	@echo "  make lint             - Run linting (flake8, black, isort)"
	@echo "  make format           - Format code (black, isort)"
	@echo "  make install-test-deps - Install test dependencies"
	@echo "  make install-hooks    - Install pre-commit hooks"
	@echo ""
	@echo "GKE Deployment (Development):"
	@echo "  make setup-gke        - Setup GKE environment (SA, IAM, secrets)"
	@echo "  make build-image      - Build custom Airflow Docker image"
	@echo "  make push-image       - Build and push image to GCR"
	@echo "  make verify-deployment - Verify GKE deployment"
	@echo ""
	@echo "Production Deployment:"
	@echo "  make create-secrets   - Create Kubernetes secrets for production"
	@echo "  make setup-secret-manager - Setup Google Secret Manager integration"
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

# Production Commands
create-secrets:
	@echo "Creating Kubernetes secrets for production..."
	@./scripts/create-secrets.sh

setup-secret-manager:
	@echo "Setting up Google Secret Manager..."
	@./scripts/setup-secret-manager.sh

# Testing Commands
install-test-deps:
	@echo "Installing test dependencies..."
	pip install -r requirements-test.txt
	@echo "✅ Test dependencies installed"

install-hooks:
	@echo "Installing pre-commit hooks..."
	pre-commit install
	@echo "✅ Pre-commit hooks installed"

test:
	@echo "Running all tests..."
	pytest tests/ -v

test-dags:
	@echo "Running DAG validation tests..."
	pytest tests/dags/ -v

test-unit:
	@echo "Running unit tests..."
	pytest tests/unit/ -v -m unit

test-integration:
	@echo "Running integration tests..."
	pytest tests/integration/ -v -m integration

lint:
	@echo "Running linters..."
	@echo "→ flake8"
	flake8 dags/ --max-line-length=100
	@echo "→ black (check)"
	black --check dags/
	@echo "→ isort (check)"
	isort --check-only dags/
	@echo "✅ Linting complete"

format:
	@echo "Formatting code..."
	black dags/
	isort dags/
	@echo "✅ Code formatted"

# Cleanup
clean: local-clean
	@echo "Cleaning build artifacts..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@rm -rf htmlcov/ .coverage junit/
	@echo "Clean complete!"
