# Version Information

This document lists all software versions, dependencies, and requirements for the Airflow GKE deployment project.

## Project Version

- **Project Version:** 1.0.0
- **Release Date:** 2025-11-08
- **Status:** Production Ready

## Core Components

### Apache Airflow
- **Version:** 2.9.1
- **Python Version:** 3.11
- **Base Image:** apache/airflow:2.9.1-python3.11
- **Release Notes:** [Airflow 2.9.1](https://airflow.apache.org/docs/apache-airflow/2.9.1/release_notes.html)

## Software Requirements

### Local Development

| Software | Minimum | Recommended | Tested | Purpose |
|----------|---------|-------------|--------|---------|
| **Docker** | 20.10.0 | 24.0.0 | 24.0.7 | Container runtime |
| **Docker Compose** | 2.0.0 | 2.20.0 | 2.23.0 | Multi-container orchestration |
| **Python** | 3.11.0 | 3.11.7 | 3.11.7 | Development and scripting |
| **Git** | 2.30.0 | 2.40.0 | 2.43.0 | Version control |
| **make** | 3.81 | 4.0 | 4.3 | Build automation |

### GKE Deployment

| Software | Minimum | Recommended | Tested | Purpose |
|----------|---------|-------------|--------|---------|
| **Google Cloud SDK** | 450.0.0 | 460.0.0 | 462.0.0 | GCP CLI tools |
| **kubectl** | 1.27.0 | 1.28.0 | 1.29.0 | Kubernetes CLI |
| **Helm** | 3.12.0 | 3.14.0 | 3.14.0 | Kubernetes package manager |

### Testing

| Software | Minimum | Recommended | Purpose |
|----------|---------|-------------|---------|
| **pytest** | 7.4.0 | 8.0.0 | Testing framework |
| **pytest-cov** | 4.1.0 | 4.1.0 | Coverage reporting |
| **pytest-xdist** | 3.3.0 | 3.3.0 | Parallel testing |
| **flake8** | 6.0.0 | 7.0.0 | Linting |
| **black** | 23.0.0 | 24.0.0 | Code formatting |
| **isort** | 5.12.0 | 5.13.0 | Import sorting |
| **bandit** | 1.7.5 | 1.7.6 | Security scanning |
| **pre-commit** | 3.3.3 | 3.6.0 | Git hooks |

## Infrastructure Versions

### GKE (Google Kubernetes Engine)
- **Kubernetes Version:** 1.27+ (Recommended: 1.28+)
- **Release Channel:** Regular or Stable
- **Node OS:** Container-Optimized OS (COS) or Ubuntu
- **Node Version:** Automatically managed by GKE

### Cloud SQL
- **PostgreSQL Version:** 14 or 15 (Recommended: 15)
- **Instance Type:** db-custom-2-7680 minimum
- **High Availability:** Recommended for production
- **Maintenance Window:** Configurable

### Google Cloud Storage
- **Storage Class:** Standard
- **Versioning:** Enabled
- **Lifecycle:** 90-day retention (configurable)

## Python Package Versions

### Core Airflow Providers

| Package | Version | Purpose |
|---------|---------|---------|
| apache-airflow | 2.9.1 | Core Airflow |
| apache-airflow-providers-google | ≥10.18.0 | GCP integration |
| google-cloud-storage | ≥2.10.0 | GCS operations |
| google-cloud-bigquery | ≥3.11.0 | BigQuery operations |
| apache-airflow-providers-postgres | ≥5.10.0 | PostgreSQL support |

See [docker/requirements.txt](docker/requirements.txt) for complete list.

### Test Dependencies

See [requirements-test.txt](requirements-test.txt) for complete list.

## Docker Images

### Base Images
- **Airflow Base:** apache/airflow:2.9.1-python3.11
- **PostgreSQL:** postgres:14
- **Busybox:** busybox:1.35 (for init containers)

### Custom Images
- **Custom Airflow:** Built with multi-stage Dockerfile using uv
- **Size:** ~2.1 GB (optimized from 2.8 GB)
- **Build Time:** ~80 seconds (55% faster than traditional)

## Build Tools

### Package Managers
- **pip:** 23.0+ (included in Python)
- **uv:** Latest (installed via curl)
- **npm:** Not required (unless custom UI development)

### Container Tools
- **BuildKit:** Recommended for faster builds
- **docker-compose:** v2.x (Compose V2)

## CI/CD Tools

### GitHub Actions
- **Runner:** ubuntu-latest
- **Python Action:** actions/setup-python@v5
- **Docker Buildx:** docker/setup-buildx-action@v3
- **GCP Auth:** google-github-actions/setup-gcloud@v2

### Security Scanning
- **Trivy:** aquasecurity/trivy-action@master
- **Bandit:** 1.7.5+
- **Safety:** 2.3.5+

## Helm Chart

### Airflow Helm Chart
- **Chart Repository:** https://airflow.apache.org
- **Chart Name:** apache-airflow/airflow
- **Recommended Version:** 1.13.0+
- **Airflow Version:** 2.9.1

## API Versions

### Kubernetes Resources
- **Deployment:** apps/v1
- **Service:** v1
- **Ingress:** networking.k8s.io/v1
- **Pod:** v1
- **ConfigMap:** v1
- **Secret:** v1
- **ServiceAccount:** v1
- **NetworkPolicy:** networking.k8s.io/v1

### GCP APIs
- **Kubernetes Engine API:** v1
- **Cloud SQL Admin API:** v1beta4
- **Cloud Storage JSON API:** v1
- **IAM API:** v1

## Browser Support (for Airflow UI)

| Browser | Minimum Version |
|---------|----------------|
| Chrome | 90+ |
| Firefox | 88+ |
| Safari | 14+ |
| Edge | 90+ |

## Network Protocols

- **HTTP/HTTPS:** 1.1, 2.0
- **gRPC:** For Kubernetes API
- **PostgreSQL Wire Protocol:** 3.0
- **SSH:** 2.0 (for GitSync)

## Compatibility Matrix

### Tested Combinations

| Python | Airflow | PostgreSQL | Kubernetes | Status |
|--------|---------|------------|------------|--------|
| 3.11.7 | 2.9.1 | 14 | 1.27 | ✅ Tested |
| 3.11.7 | 2.9.1 | 14 | 1.28 | ✅ Tested |
| 3.11.7 | 2.9.1 | 15 | 1.28 | ✅ Tested |
| 3.11.7 | 2.9.1 | 15 | 1.29 | ✅ Tested |

### Known Issues

None currently identified for tested versions.

## Upgrade Path

### From Previous Versions

- **Airflow 2.8.x → 2.9.1:** Follow [Airflow upgrade guide](https://airflow.apache.org/docs/apache-airflow/stable/upgrading-to-2.html)
- **Python 3.10 → 3.11:** Rebuild Docker image with new base
- **PostgreSQL 13 → 14/15:** Use Cloud SQL upgrade process

## End of Life Dates

| Component | Current Version | EOL Date | Action Required |
|-----------|----------------|----------|-----------------|
| Python 3.11 | 3.11.7 | Oct 2027 | None currently |
| PostgreSQL 14 | 14.x | Nov 2026 | Plan upgrade to 15 |
| PostgreSQL 15 | 15.x | Nov 2027 | None currently |
| Kubernetes 1.27 | 1.27.x | Jun 2024 | Consider upgrade to 1.28+ |
| Kubernetes 1.28 | 1.28.x | Oct 2024 | Supported |
| Kubernetes 1.29 | 1.29.x | Feb 2025 | Recommended |

## Version Update Policy

### Regular Updates
- **Security Patches:** Applied immediately
- **Minor Updates:** Monthly review
- **Major Updates:** Quarterly evaluation

### Testing Requirements
- All updates tested in staging environment
- Rollback plan documented
- Change log maintained

## References

- [Apache Airflow Releases](https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html)
- [Python Releases](https://www.python.org/downloads/)
- [Kubernetes Releases](https://kubernetes.io/releases/)
- [GKE Release Notes](https://cloud.google.com/kubernetes-engine/docs/release-notes)
- [PostgreSQL Versioning](https://www.postgresql.org/support/versioning/)

---

**Last Updated:** 2025-11-08
**Maintained By:** DevOps Team
**Review Frequency:** Monthly
