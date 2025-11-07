#!/bin/bash

# Exit on error
set -e

# Configuration - Update these values
PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
REGION="${GCP_REGION:-us-central1}"
CLUSTER_NAME="${GKE_CLUSTER_NAME:-airflow-cluster}"
NAMESPACE="${K8S_NAMESPACE:-default}"
GCS_BUCKET="${GCS_BUCKET_NAME:-your-airflow-bucket}"
KSA_NAME="airflow-sa"  # Kubernetes Service Account
GSA_NAME="airflow-gke"  # Google Service Account

echo "================================================"
echo "Setting up GKE Environment for Airflow"
echo "================================================"
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Cluster: ${CLUSTER_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "GCS Bucket: ${GCS_BUCKET}"
echo "K8s Service Account: ${KSA_NAME}"
echo "Google Service Account: ${GSA_NAME}"
echo "================================================"

# Prompt for confirmation
read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Set the current project
echo "Setting GCP project..."
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    storage-api.googleapis.com \
    storage-component.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    sqladmin.googleapis.com

echo "✅ APIs enabled"

# Create GCS bucket for Airflow logs
echo "Creating GCS bucket for Airflow logs..."
if gsutil ls -b gs://${GCS_BUCKET} 2>/dev/null; then
    echo "⚠️  Bucket gs://${GCS_BUCKET} already exists"
else
    gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} gs://${GCS_BUCKET}
    echo "✅ Bucket created: gs://${GCS_BUCKET}"
fi

# Enable versioning on the bucket (optional but recommended)
gsutil versioning set on gs://${GCS_BUCKET}
echo "✅ Versioning enabled on bucket"

# Create Google Service Account (GSA)
echo "Creating Google Service Account..."
if gcloud iam service-accounts describe ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com >/dev/null 2>&1; then
    echo "⚠️  Service account ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com already exists"
else
    gcloud iam service-accounts create ${GSA_NAME} \
        --display-name="Airflow GKE Service Account" \
        --project=${PROJECT_ID}
    echo "✅ Service account created"
fi

# Grant necessary permissions to GSA
echo "Granting permissions to Google Service Account..."

# Storage Admin for GCS logs
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin" \
    --condition=None

# Cloud SQL Client (if using Cloud SQL)
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/cloudsql.client" \
    --condition=None

# Add additional roles as needed for your use case
# Example: BigQuery Data Editor
# gcloud projects add-iam-policy-binding ${PROJECT_ID} \
#     --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
#     --role="roles/bigquery.dataEditor" \
#     --condition=None

echo "✅ Permissions granted"

# Get GKE credentials
echo "Getting GKE cluster credentials..."
gcloud container clusters get-credentials ${CLUSTER_NAME} \
    --region=${REGION} \
    --project=${PROJECT_ID}
echo "✅ Cluster credentials obtained"

# Create Kubernetes namespace if it doesn't exist
echo "Creating Kubernetes namespace..."
if kubectl get namespace ${NAMESPACE} >/dev/null 2>&1; then
    echo "⚠️  Namespace ${NAMESPACE} already exists"
else
    kubectl create namespace ${NAMESPACE}
    echo "✅ Namespace created"
fi

# Create Kubernetes Service Account
echo "Creating Kubernetes Service Account..."
kubectl create serviceaccount ${KSA_NAME} \
    --namespace ${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Kubernetes Service Account created/updated"

# Annotate KSA with GSA for Workload Identity
echo "Configuring Workload Identity..."
kubectl annotate serviceaccount ${KSA_NAME} \
    --namespace ${NAMESPACE} \
    iam.gke.io/gcp-service-account=${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --overwrite
echo "✅ Service Account annotated"

# Bind KSA to GSA (Workload Identity)
gcloud iam service-accounts add-iam-policy-binding \
    ${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KSA_NAME}]" \
    --project=${PROJECT_ID}
echo "✅ Workload Identity binding created"

# Generate Fernet key for Airflow
echo "Generating Fernet key..."
FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")

# Create secret for Fernet key
kubectl create secret generic airflow-fernet-key \
    --from-literal=fernet-key="${FERNET_KEY}" \
    --namespace=${NAMESPACE} \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Fernet key secret created"

# Instructions for SSH key secret (for GitSync)
echo ""
echo "================================================"
echo "⚠️  IMPORTANT: Create SSH Key Secret for GitSync"
echo "================================================"
echo "1. Generate SSH key pair if you haven't:"
echo "   ssh-keygen -t rsa -b 4096 -C 'airflow-gitsync' -f ~/.ssh/airflow-git-sync"
echo ""
echo "2. Add the public key to your Git repository (GitHub/GitLab/etc.)"
echo ""
echo "3. Create the Kubernetes secret:"
echo "   kubectl create secret generic airflow-ssh-secret \\"
echo "     --from-file=gitSshKey=~/.ssh/airflow-git-sync \\"
echo "     --namespace=${NAMESPACE}"
echo ""
echo "================================================"

# Instructions for PostgreSQL configuration
echo ""
echo "================================================"
echo "PostgreSQL Configuration"
echo "================================================"
echo "If using Cloud SQL:"
echo "1. Create a Cloud SQL PostgreSQL instance"
echo "2. Create a database named 'airflow'"
echo "3. Create a user for Airflow"
echo "4. Note the private IP address"
echo "5. Update the values.yaml file with connection details"
echo ""
echo "If using external PostgreSQL:"
echo "1. Ensure the database is accessible from GKE"
echo "2. Update the values.yaml file with connection details"
echo "================================================"

echo ""
echo "================================================"
echo "✅ Setup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Build and push your custom Airflow image:"
echo "   ./scripts/build-and-push.sh"
echo ""
echo "2. Create SSH secret for GitSync (see instructions above)"
echo ""
echo "3. Update helm-chart/values.yaml with your configuration:"
echo "   - GCP Project ID"
echo "   - GCS Bucket name"
echo "   - PostgreSQL connection details"
echo "   - Git repository URL"
echo "   - Docker image path"
echo ""
echo "4. Install Airflow with Helm:"
echo "   helm repo add apache-airflow https://airflow.apache.org"
echo "   helm repo update"
echo "   helm install airflow apache-airflow/airflow \\"
echo "     --namespace ${NAMESPACE} \\"
echo "     --values helm-chart/values.yaml"
echo ""
echo "5. Check the deployment:"
echo "   kubectl get pods -n ${NAMESPACE}"
echo ""
echo "6. Access the Airflow UI:"
echo "   kubectl port-forward svc/airflow-webserver 8080:8080 -n ${NAMESPACE}"
echo "   Open http://localhost:8080"
echo "================================================"
