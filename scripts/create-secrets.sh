#!/bin/bash

# Script to create Kubernetes secrets for Airflow production deployment
# This script generates secure secrets and creates them in Kubernetes

set -e

# Configuration
NAMESPACE="${K8S_NAMESPACE:-airflow-prod}"
DB_USER="${DB_USER:-airflow}"
DB_PASSWORD="${DB_PASSWORD}"
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-airflow}"

echo "================================================"
echo "Creating Airflow Secrets"
echo "================================================"
echo "Namespace: ${NAMESPACE}"
echo ""

# Check if namespace exists
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "Creating namespace ${NAMESPACE}..."
    kubectl create namespace ${NAMESPACE}
fi

# Function to generate random secure string
generate_secret() {
    openssl rand -base64 32
}

# Function to generate Fernet key
generate_fernet_key() {
    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
}

echo "1. Creating Fernet Key Secret..."
if kubectl get secret airflow-fernet-key -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Fernet key secret already exists. Skipping..."
else
    FERNET_KEY=$(generate_fernet_key)
    kubectl create secret generic airflow-fernet-key \
        --from-literal=fernet-key="${FERNET_KEY}" \
        --namespace=${NAMESPACE}
    echo "✅ Fernet key secret created"
fi
echo ""

echo "2. Creating Webserver Secret Key..."
if kubectl get secret airflow-webserver-secret -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Webserver secret already exists. Skipping..."
else
    WEBSERVER_SECRET_KEY=$(generate_secret)
    kubectl create secret generic airflow-webserver-secret \
        --from-literal=webserver-secret-key="${WEBSERVER_SECRET_KEY}" \
        --namespace=${NAMESPACE}
    echo "✅ Webserver secret created"
fi
echo ""

echo "3. Creating Metadata Database Connection Secret..."
if kubectl get secret airflow-metadata-secret -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Metadata secret already exists. Skipping..."
else
    if [ -z "${DB_PASSWORD}" ] || [ -z "${DB_HOST}" ]; then
        echo "❌ Error: DB_PASSWORD and DB_HOST must be set"
        echo "   Example: DB_PASSWORD=xxx DB_HOST=10.x.x.x ./create-secrets.sh"
        exit 1
    fi

    # PostgreSQL connection URI
    # Format: postgresql://user:password@host:port/database
    CONNECTION_URI="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"

    kubectl create secret generic airflow-metadata-secret \
        --from-literal=connection="${CONNECTION_URI}" \
        --namespace=${NAMESPACE}
    echo "✅ Metadata database secret created"
fi
echo ""

echo "4. Creating General Environment Secret..."
if kubectl get secret airflow-env-secret -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Environment secret already exists. Skipping..."
else
    # Create a generic secret for other environment variables
    kubectl create secret generic airflow-env-secret \
        --from-literal=AIRFLOW__SMTP__SMTP_USER="${SMTP_USER:-}" \
        --from-literal=AIRFLOW__SMTP__SMTP_PASSWORD="${SMTP_PASSWORD:-}" \
        --namespace=${NAMESPACE}
    echo "✅ Environment secret created"
fi
echo ""

echo "5. Creating Scheduler Secret..."
if kubectl get secret airflow-scheduler-secret -n ${NAMESPACE} &> /dev/null; then
    echo "⚠️  Scheduler secret already exists. Skipping..."
else
    kubectl create secret generic airflow-scheduler-secret \
        --from-literal=scheduler-secret="$(generate_secret)" \
        --namespace=${NAMESPACE}
    echo "✅ Scheduler secret created"
fi
echo ""

echo "================================================"
echo "SSH Key Secret for GitSync"
echo "================================================"
echo ""
echo "To create the SSH key secret for GitSync:"
echo ""
echo "1. Generate SSH key (if not already done):"
echo "   ssh-keygen -t rsa -b 4096 -C 'airflow-gitsync' -f ~/.ssh/airflow-git-sync -N ''"
echo ""
echo "2. Add public key to your Git repository:"
echo "   cat ~/.ssh/airflow-git-sync.pub"
echo "   (Add this to GitHub Deploy Keys or GitLab Deploy Keys)"
echo ""
echo "3. Create Kubernetes secret:"
echo "   kubectl create secret generic airflow-ssh-secret \\"
echo "     --from-file=gitSshKey=~/.ssh/airflow-git-sync \\"
echo "     --namespace=${NAMESPACE}"
echo ""

# Optional: Create secret for GCP service account key (if not using Workload Identity)
echo "================================================"
echo "GCP Service Account Key (Optional)"
echo "================================================"
echo ""
echo "If NOT using Workload Identity, create GCP SA key secret:"
echo ""
echo "1. Create and download service account key:"
echo "   gcloud iam service-accounts keys create ~/gcp-key.json \\"
echo "     --iam-account=airflow-gke@PROJECT_ID.iam.gserviceaccount.com"
echo ""
echo "2. Create Kubernetes secret:"
echo "   kubectl create secret generic airflow-gcp-key \\"
echo "     --from-file=key.json=~/gcp-key.json \\"
echo "     --namespace=${NAMESPACE}"
echo ""
echo "⚠️  Note: Using Workload Identity is recommended over SA keys"
echo ""

echo "================================================"
echo "✅ Secret Creation Complete!"
echo "================================================"
echo ""
echo "Verify secrets:"
echo "  kubectl get secrets -n ${NAMESPACE}"
echo ""
echo "View secret details (without values):"
echo "  kubectl describe secret airflow-fernet-key -n ${NAMESPACE}"
echo ""
echo "⚠️  IMPORTANT SECURITY NOTES:"
echo "  1. Never commit these secrets to version control"
echo "  2. Rotate secrets regularly (every 90 days recommended)"
echo "  3. Use Google Secret Manager for production"
echo "  4. Limit access to secrets using RBAC"
echo "  5. Enable audit logging for secret access"
echo "================================================"
