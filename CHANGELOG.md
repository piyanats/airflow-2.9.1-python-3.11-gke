# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Detailed version requirements documentation (VERSION.md)
- Comprehensive software version tables in README.md
- Extended prerequisites section in PRODUCTION-DEPLOYMENT.md
- Infrastructure requirements and specifications
- Cost estimation tables for production deployment
- Resource quota requirements
- Knowledge prerequisites checklist
- Installation verification commands
- Compatibility matrix
- End of life dates for dependencies

### Changed
- Enhanced README prerequisites with version tables
- Updated PRODUCTION-DEPLOYMENT prerequisites with detailed versions
- Added installation guides and reference links
- Improved documentation clarity with specific versions

## [1.1.0] - 2025-11-08

### Added
- Comprehensive testing infrastructure
  - DAG validation tests (15+ test cases)
  - Unit test structure
  - Integration test structure
  - pytest configuration
  - Test fixtures and conftest.py
- Test dependencies (requirements-test.txt)
- GitHub Actions CI/CD pipeline (6 jobs)
- Pre-commit hooks configuration (10+ hooks)
- Code quality tools (flake8, black, isort, pylint, bandit)
- Security scanning with Trivy
- Testing documentation guide (docs/testing-guide.md)
- Makefile test commands (test, lint, format, install-hooks)
- Project review documentation (PROJECT-REVIEW.md)
- Comprehensive troubleshooting guide (docs/troubleshooting.md)
- Kubernetes pod template for worker customization
- .gitkeep files for empty directories

### Fixed
- Critical Dockerfile permission issue with uv package manager
- Virtual environment ownership for multi-user Docker builds

### Changed
- Updated README with testing section
- Enhanced Makefile with testing and quality targets

## [1.0.0] - 2025-11-08

### Added
- Apache Airflow 2.9.1 with Python 3.11 deployment setup
- Multi-stage Dockerfile with uv package manager for fast builds
- Docker Compose configuration for local development
- Helm chart configurations (development and production)
- GKE setup script with Workload Identity
- Production deployment guide with best practices
- Configuration comparison documentation (dev vs prod)
- Docker build optimization guide
- Automated scripts for:
  - Building and pushing Docker images to GCR
  - Setting up GKE environment
  - Creating Kubernetes secrets
  - Setting up Google Secret Manager
  - Verifying deployments
  - Testing local environment
- Example DAGs for testing
- Makefile for common operations

### Features
- **High Availability**: Multiple replicas for webserver, scheduler, triggerer
- **Security**: Workload Identity, RBAC, network policies
- **Monitoring**: StatsD/Prometheus integration
- **Logging**: GCS remote logging
- **GitSync**: Automatic DAG synchronization with SSH
- **Database**: External PostgreSQL support (Cloud SQL)
- **Connection Pooling**: PgBouncer configuration
- **Optimization**: 55% faster builds, 25% smaller images

### Documentation
- Comprehensive README with quick start guides
- Production deployment guide with checklists
- Configuration comparison guide
- Docker build optimization guide
- Troubleshooting guide

### Infrastructure
- GKE cluster with Workload Identity
- Cloud SQL PostgreSQL
- GCS bucket for logs
- Google Container Registry for images
- Kubernetes service accounts and RBAC

## [0.2.0] - 2025-11-08

### Added
- Production Helm values with HA configuration
- Secrets management scripts
- Google Secret Manager integration
- Configuration comparison documentation

### Changed
- Enhanced security configurations
- Improved resource allocations
- Better monitoring setup

## [0.1.0] - 2025-11-08

### Added
- Initial project structure
- Basic Dockerfile
- Basic Helm values
- Setup scripts
- Docker Compose for local development

---

## Version Naming Convention

- **Major version (X.0.0)**: Breaking changes, major feature additions
- **Minor version (0.X.0)**: New features, non-breaking changes
- **Patch version (0.0.X)**: Bug fixes, documentation updates

## Types of Changes

- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security improvements

## Links

- [Repository](https://github.com/your-org/airflow-2.9.1-python-3.11-gke)
- [Issues](https://github.com/your-org/airflow-2.9.1-python-3.11-gke/issues)
- [Pull Requests](https://github.com/your-org/airflow-2.9.1-python-3.11-gke/pulls)
