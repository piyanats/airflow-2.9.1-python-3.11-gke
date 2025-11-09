# Apache Airflow 2.9.1 on GKE with Python 3.11

This repository contains all the necessary files and scripts to deploy Apache Airflow 2.9.1 with Python 3.11 on Google Kubernetes Engine (GKE) with Workload Identity, external PostgreSQL, GCS logging, and GitSync.

> **📚 For Production Deployments**: See the comprehensive [Production Deployment Guide](PRODUCTION-DEPLOYMENT.md) for best practices, security hardening, and step-by-step production setup.

> **⚖️ Development vs Production**: Review the [Configuration Comparison](docs/configuration-comparison.md) to understand differences between development and production configurations.

## Features

- **Apache Airflow 2.9.1** with **Python 3.11**
- **Optimized Docker Image** with multi-stage build and uv package manager (faster builds, smaller images)
- **GKE Workload Identity** for secure access to GCP services
- **External PostgreSQL** support (Google Cloud SQL or external host)
- **GCS bucket** for remote logging
- **GitSync** for DAG synchronization with SSH key authentication
- **Docker Compose** for local development and testing
- **Automated setup scripts** for GKE environment preparation
- **Production-ready configuration** with HA, monitoring, and security best practices

## Project Structure

```
.
├── docker/
│   ├── Dockerfile                    # Multi-stage Dockerfile with uv
│   ├── .dockerignore                 # Docker build optimization
│   └── requirements.txt              # Python dependencies
├── helm-chart/
│   ├── values.yaml                   # Development Helm configuration
│   └── values-production.yaml        # Production Helm configuration
├── scripts/
│   ├── build-and-push.sh             # Build and push Docker image to GCR
│   ├── setup-gke.sh                  # Setup GKE environment
│   ├── create-secrets.sh             # Create Kubernetes secrets
│   ├── setup-secret-manager.sh       # Setup Google Secret Manager
│   ├── verify-deployment.sh          # Verify GKE deployment
│   └── test-local.sh                 # Test local deployment
├── dags/                              # Airflow DAGs directory
│   ├── example_dag.py                # Example DAG
│   └── example_gcs_dag.py            # Example GCS DAG
├── plugins/                           # Airflow plugins directory
├── config/                            # Airflow configuration files
├── docs/
│   ├── configuration-comparison.md   # Dev vs Prod comparison
│   └── docker-build-guide.md         # Docker build optimization guide
├── docker-compose.yaml               # Local development setup
├── .env.example                      # Environment variables template
├── Makefile                          # Convenient commands
├── README.md                         # This file
└── PRODUCTION-DEPLOYMENT.md          # Production deployment guide
```

## Testing

The project includes comprehensive testing infrastructure for DAG validation and code quality.

### Quick Test Commands

```bash
# Install test dependencies
make install-test-deps

# Run all tests
make test

# Run specific tests
make test-dags          # DAG validation
make test-unit          # Unit tests
make test-integration   # Integration tests

# Code quality
make lint               # Run linters
make format             # Format code

# Pre-commit hooks
make install-hooks      # Install git hooks
```

### Test Structure

- **DAG Validation Tests** - Ensure DAGs load correctly and follow best practices
- **Unit Tests** - Test individual components
- **Integration Tests** - Test complete workflows
- **CI/CD Pipeline** - Automated testing on every commit

See [Testing Guide](docs/testing-guide.md) for complete documentation.

## Prerequisites

### Software Requirements

#### Local Development

| Software | Minimum Version | Recommended | Tested With |
|----------|----------------|-------------|-------------|
| **Docker** | 20.10.0 | 24.0.0+ | 24.0.7 |
| **Docker Compose** | 2.0.0 | 2.20.0+ | 2.23.0 |
| **Python** | 3.11.0 | 3.11.7+ | 3.11.7 |
| **Git** | 2.30.0 | 2.40.0+ | 2.43.0 |

**Installation Verification:**
```bash
docker --version          # Docker version 24.0.7
docker-compose --version  # Docker Compose version 2.23.0
python3 --version         # Python 3.11.7
git --version            # git version 2.43.0
```

#### Testing (Optional)

| Software | Minimum Version | Recommended |
|----------|----------------|-------------|
| **pytest** | 7.4.0 | 8.0.0+ |
| **pre-commit** | 3.0.0 | 3.5.0+ |

Install with: `make install-test-deps`

#### GKE Deployment

| Software | Minimum Version | Recommended | Tested With |
|----------|----------------|-------------|-------------|
| **Google Cloud SDK** | 450.0.0 | 460.0.0+ | 462.0.0 |
| **kubectl** | 1.27.0 | 1.28.0+ | 1.29.0 |
| **Helm** | 3.12.0 | 3.14.0+ | 3.14.0 |

**Installation Verification:**
```bash
gcloud version           # Google Cloud SDK 462.0.0
kubectl version --client # Client Version: v1.29.0
helm version            # Version: v3.14.0
```

**Installation Guides:**
- [Install Docker](https://docs.docker.com/engine/install/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)
- [Install Python 3.11](https://www.python.org/downloads/)
- [Install gcloud SDK](https://cloud.google.com/sdk/docs/install)
- [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Install Helm](https://helm.sh/docs/intro/install/)

### Infrastructure Requirements

#### GKE Cluster
- **Kubernetes Version:** 1.27+ (Recommended: 1.28+)
- **Node Pool:** Minimum 3 nodes
- **Machine Type:** n1-standard-2 or better (Recommended: n1-standard-4)
- **Workload Identity:** Enabled
- **GKE Version:** Regular or Stable release channel

#### Cloud SQL (PostgreSQL)
- **PostgreSQL Version:** 14 or 15
- **Instance Type:** db-custom-2-7680 minimum (Recommended: db-custom-4-15360)
- **High Availability:** Recommended for production
- **Private IP:** Required for secure connection

#### Google Cloud Storage
- **Bucket:** Standard storage class
- **Region:** Same as GKE cluster
- **Versioning:** Enabled (Recommended)

#### Network
- **VPC:** Default or custom VPC
- **Subnet:** IP range for GKE nodes
- **Firewall:** Allow internal communication

### Access Requirements

- **GCP Project:** With billing enabled
- **IAM Permissions:**
  - Kubernetes Engine Admin
  - Storage Admin
  - Cloud SQL Admin
  - Service Account Admin
  - IAM Security Admin
- **API Enablement:**
  - Kubernetes Engine API
  - Cloud SQL Admin API
  - Cloud Storage API
  - Container Registry API

## Quick Start

### 1. Local Development with Docker Compose

#### Step 1: Setup Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env file with your settings
nano .env

# On Linux, set AIRFLOW_UID to your user ID
echo "AIRFLOW_UID=$(id -u)" >> .env
```

#### Step 2: Initialize and Start Airflow

```bash
# Create required directories
mkdir -p ./dags ./logs ./plugins ./config

# Start Airflow services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

#### Step 3: Access Airflow UI

Open your browser and navigate to: `http://localhost:8080`

- **Username**: `admin` (or as configured in .env)
- **Password**: `admin` (or as configured in .env)

#### Step 4: Stop Services

```bash
docker-compose down

# To remove volumes as well
docker-compose down -v
```

### 2. GKE Deployment

> **⚠️ Note**: This section provides a quick development deployment. For production deployments with high availability, security hardening, and monitoring, see the [Production Deployment Guide](PRODUCTION-DEPLOYMENT.md).

#### Prerequisites

1. **Create or use existing GKE cluster with Workload Identity enabled**:

```bash
gcloud container clusters create airflow-cluster \
  --region us-central1 \
  --workload-pool=YOUR-PROJECT-ID.svc.id.goog \
  --enable-ip-alias \
  --num-nodes=3 \
  --machine-type=n1-standard-2
```

2. **Prepare PostgreSQL Database**:

   - **Option A: Cloud SQL**:
     ```bash
     gcloud sql instances create airflow-db \
       --database-version=POSTGRES_14 \
       --tier=db-custom-2-7680 \
       --region=us-central1 \
       --network=default \
       --no-assign-ip

     gcloud sql databases create airflow --instance=airflow-db
     gcloud sql users create airflow --instance=airflow-db --password=CHANGE_ME
     ```

   - **Option B: External PostgreSQL**: Ensure it's accessible from GKE

#### Step 1: Configure Environment

```bash
# Set environment variables
export GCP_PROJECT_ID="your-gcp-project-id"
export GCP_REGION="us-central1"
export GKE_CLUSTER_NAME="airflow-cluster"
export GCS_BUCKET_NAME="your-airflow-bucket"
```

#### Step 2: Run GKE Setup Script

This script will:
- Enable required GCP APIs
- Create GCS bucket for logs
- Create and configure service accounts
- Setup Workload Identity bindings
- Create Kubernetes namespace and secrets

```bash
./scripts/setup-gke.sh
```

#### Step 3: Generate and Add SSH Key for GitSync

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -C "airflow-gitsync" -f ~/.ssh/airflow-git-sync

# Add the public key to your Git repository
# (GitHub: Settings > Deploy keys, GitLab: Settings > Repository > Deploy keys)
cat ~/.ssh/airflow-git-sync.pub

# Create Kubernetes secret
kubectl create secret generic airflow-ssh-secret \
  --from-file=gitSshKey=~/.ssh/airflow-git-sync \
  --namespace=default
```

#### Step 4: Build and Push Custom Docker Image

> **💡 Optimization**: The Dockerfile uses multi-stage build with uv package manager for 10-100x faster builds and 25% smaller images. See [Docker Build Guide](docs/docker-build-guide.md) for details.

```bash
# Set environment variables for the build script
export GCP_PROJECT_ID="your-gcp-project-id"
export IMAGE_TAG="2.9.1-python3.11"
export GCR_REGION="us"

# Build and push the image (uses multi-stage build with uv)
./scripts/build-and-push.sh

# The build process:
# Stage 1: Install dependencies with uv (fast!)
# Stage 2: Copy only runtime files (smaller image)
```

#### Step 5: Configure Helm Values

Edit `helm-chart/values.yaml` and update the following values:

- `images.airflow.repository`: Your GCR image path
- `images.airflow.tag`: Your image tag
- `config.logging.remote_base_log_folder`: Your GCS bucket path
- `data.metadataConnection.host`: Your PostgreSQL host
- `data.metadataConnection.user`: Your PostgreSQL user
- `data.metadataConnection.pass`: Your PostgreSQL password
- `serviceAccount.annotations`: Your GSA email
- `dags.gitSync.repo`: Your Git repository URL
- Replace all `YOUR-PROJECT-ID` and `YOUR-GCS-BUCKET` placeholders

#### Step 6: Install Airflow with Helm

```bash
# Add Airflow Helm repository
helm repo add apache-airflow https://airflow.apache.org
helm repo update

# Install Airflow
helm install airflow apache-airflow/airflow \
  --namespace default \
  --values helm-chart/values.yaml \
  --timeout 10m

# Check deployment status
kubectl get pods -n default

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=airflow --timeout=300s -n default
```

#### Step 7: Access Airflow UI

```bash
# Port forward to access locally
kubectl port-forward svc/airflow-webserver 8080:8080 -n default

# Or get the LoadBalancer IP (if using LoadBalancer service type)
kubectl get svc airflow-webserver -n default
```

Open your browser: `http://localhost:8080`

- **Username**: `admin` (as configured in values.yaml)
- **Password**: `admin` (as configured in values.yaml)

## Configuration Details

### Workload Identity Setup

Workload Identity allows your Airflow pods to authenticate to GCP services without using service account keys.

The setup script automatically configures:
1. Google Service Account (GSA): `airflow-gke@PROJECT_ID.iam.gserviceaccount.com`
2. Kubernetes Service Account (KSA): `airflow-sa`
3. IAM binding between GSA and KSA
4. Required IAM roles (Storage Admin, Cloud SQL Client)

### External PostgreSQL

Update the `data.metadataConnection` section in `helm-chart/values.yaml`:

```yaml
data:
  metadataConnection:
    user: airflow
    pass: your-secure-password
    protocol: postgresql
    host: 10.x.x.x  # Cloud SQL private IP or external host
    port: 5432
    db: airflow
    sslmode: require  # or disable
```

### GCS Logging

Logs are automatically uploaded to GCS. Configure in `helm-chart/values.yaml`:

```yaml
config:
  logging:
    remote_logging: 'true'
    remote_base_log_folder: 'gs://your-bucket/airflow/logs'
    remote_log_conn_id: 'google_cloud_default'
```

### GitSync Configuration

DAGs are synchronized from a Git repository using SSH authentication:

```yaml
dags:
  gitSync:
    enabled: true
    repo: git@github.com:your-org/your-repo.git
    branch: main
    subPath: "dags"
    sshKeySecret: airflow-ssh-secret
```

### Custom Docker Image

Add your Python dependencies to `docker/requirements.txt`:

```txt
# Your custom packages
pandas>=2.0.0
requests>=2.31.0
your-custom-package>=1.0.0
```

Then rebuild and push:

```bash
./scripts/build-and-push.sh
```

## Upgrading Airflow

To upgrade to a newer version:

1. Update the Dockerfile base image:
   ```dockerfile
   FROM apache/airflow:2.x.x-python3.11
   ```

2. Update `airflowVersion` in `helm-chart/values.yaml`

3. Rebuild and push the Docker image

4. Upgrade Helm release:
   ```bash
   helm upgrade airflow apache-airflow/airflow \
     --namespace default \
     --values helm-chart/values.yaml
   ```

## Monitoring and Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n default
kubectl describe pod <pod-name> -n default
kubectl logs <pod-name> -n default
```

### Check Airflow Logs

```bash
# Webserver logs
kubectl logs -l component=webserver -n default

# Scheduler logs
kubectl logs -l component=scheduler -n default

# Worker logs (if any)
kubectl logs -l component=worker -n default
```

### Access Airflow Database

```bash
# Port forward to PostgreSQL
kubectl port-forward svc/postgres 5432:5432 -n default

# Connect using psql
psql -h localhost -U airflow -d airflow
```

### GitSync Troubleshooting

```bash
# Check git-sync container logs
kubectl logs <scheduler-pod> -c git-sync -n default

# Verify SSH secret
kubectl get secret airflow-ssh-secret -n default -o yaml
```

### Common Issues

1. **Pods stuck in Pending**: Check node resources and PVC bindings
2. **GitSync fails**: Verify SSH key and repository access
3. **Database connection fails**: Check PostgreSQL connectivity and credentials
4. **GCS logging fails**: Verify Workload Identity and IAM permissions

## Security Best Practices

1. **Use Secrets**: Store sensitive data in Kubernetes Secrets, not in values.yaml
2. **Enable SSL**: Use SSL for PostgreSQL and enable HTTPS for webserver
3. **Restrict Access**: Use Network Policies and Private GKE clusters
4. **Rotate Credentials**: Regularly rotate database passwords and SSH keys
5. **Limit Permissions**: Grant minimum required IAM roles
6. **Enable Audit Logs**: Enable GKE and Airflow audit logging

## Production Recommendations

1. **Resource Limits**: Adjust resource requests/limits based on workload
2. **Autoscaling**: Enable horizontal pod autoscaling for workers
3. **Monitoring**: Integrate with Cloud Monitoring and Logging
4. **Backups**: Regularly backup PostgreSQL database and GCS logs
5. **High Availability**: Run multiple replicas of webserver and scheduler
6. **Load Balancer**: Use internal load balancer for production
7. **Custom Domain**: Configure Ingress with SSL certificate

## Cleanup

### Local Environment

```bash
docker-compose down -v
docker system prune -a
```

### GKE Environment

```bash
# Uninstall Helm release
helm uninstall airflow -n default

# Delete Kubernetes resources
kubectl delete secret airflow-ssh-secret -n default
kubectl delete secret airflow-fernet-key -n default
kubectl delete serviceaccount airflow-sa -n default

# Delete GCP resources (careful!)
gsutil rm -r gs://your-airflow-bucket
gcloud iam service-accounts delete airflow-gke@PROJECT_ID.iam.gserviceaccount.com

# Delete GKE cluster
gcloud container clusters delete airflow-cluster --region us-central1
```

## Additional Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/)
- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)

## License

This project configuration is provided as-is for deploying Apache Airflow.

## Support

For issues and questions:
- Airflow: [Apache Airflow Slack](https://apache-airflow.slack.com/)
- GKE: [Google Cloud Support](https://cloud.google.com/support)
