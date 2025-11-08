#!/bin/bash

# Script to integrate Google Secret Manager with Airflow
# This is recommended for production deployments instead of Kubernetes secrets

set -e

PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
NAMESPACE="${K8S_NAMESPACE:-airflow-prod}"
GSA_NAME="${GSA_NAME:-airflow-gke}"

echo "================================================"
echo "Setting up Google Secret Manager Integration"
echo "================================================"
echo "Project: ${PROJECT_ID}"
echo "Namespace: ${NAMESPACE}"
echo "Service Account: ${GSA_NAME}"
echo ""

# Enable Secret Manager API
echo "1. Enabling Secret Manager API..."
gcloud services enable secretmanager.googleapis.com --project=${PROJECT_ID}
echo "✅ API enabled"
echo ""

# Grant Secret Manager permissions to GSA
echo "2. Granting Secret Manager permissions..."
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${GSA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/secretmanager.secretAccessor"

echo "✅ Permissions granted"
echo ""

# Function to create secret in Secret Manager
create_secret() {
    local SECRET_NAME=$1
    local SECRET_VALUE=$2

    echo "Creating secret: ${SECRET_NAME}..."

    # Check if secret exists
    if gcloud secrets describe ${SECRET_NAME} --project=${PROJECT_ID} &>/dev/null; then
        echo "⚠️  Secret ${SECRET_NAME} already exists. Adding new version..."
        echo -n "${SECRET_VALUE}" | gcloud secrets versions add ${SECRET_NAME} \
            --data-file=- \
            --project=${PROJECT_ID}
    else
        echo -n "${SECRET_VALUE}" | gcloud secrets create ${SECRET_NAME} \
            --data-file=- \
            --replication-policy="automatic" \
            --project=${PROJECT_ID}
    fi

    echo "✅ Secret ${SECRET_NAME} created/updated"
}

# Generate secrets
echo "3. Creating secrets in Secret Manager..."
echo ""

# Fernet Key
if [ -z "${FERNET_KEY}" ]; then
    FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
fi
create_secret "airflow-fernet-key" "${FERNET_KEY}"

# Webserver Secret Key
if [ -z "${WEBSERVER_SECRET_KEY}" ]; then
    WEBSERVER_SECRET_KEY=$(openssl rand -base64 32)
fi
create_secret "airflow-webserver-secret-key" "${WEBSERVER_SECRET_KEY}"

# Database password
if [ -n "${DB_PASSWORD}" ]; then
    create_secret "airflow-db-password" "${DB_PASSWORD}"
else
    echo "⚠️  DB_PASSWORD not set. Skipping database password secret."
fi

# SMTP password (if provided)
if [ -n "${SMTP_PASSWORD}" ]; then
    create_secret "airflow-smtp-password" "${SMTP_PASSWORD}"
fi

echo ""
echo "4. Installing External Secrets Operator (optional)..."
echo ""
echo "To use Google Secret Manager with Kubernetes, you can:"
echo ""
echo "Option 1: Use External Secrets Operator (recommended)"
echo "  helm repo add external-secrets https://charts.external-secrets.io"
echo "  helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace"
echo ""
echo "Then create a SecretStore:"
cat <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm-secret-store
  namespace: airflow-prod
spec:
  provider:
    gcpsm:
      projectID: "YOUR-PROJECT-ID"
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: airflow-prod
          serviceAccountRef:
            name: airflow-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: airflow-secrets
  namespace: airflow-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcpsm-secret-store
    kind: SecretStore
  target:
    name: airflow-fernet-key
    creationPolicy: Owner
  data:
  - secretKey: fernet-key
    remoteRef:
      key: airflow-fernet-key
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: airflow-webserver-secret
  namespace: airflow-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcpsm-secret-store
    kind: SecretStore
  target:
    name: airflow-webserver-secret
    creationPolicy: Owner
  data:
  - secretKey: webserver-secret-key
    remoteRef:
      key: airflow-webserver-secret-key
EOF
echo ""
echo "Option 2: Use GKE Workload Identity with init containers"
echo "  (Access secrets directly from application code using Google client libraries)"
echo ""

echo "================================================"
echo "✅ Google Secret Manager Setup Complete!"
echo "================================================"
echo ""
echo "Secrets created in Secret Manager:"
echo "  - airflow-fernet-key"
echo "  - airflow-webserver-secret-key"
if [ -n "${DB_PASSWORD}" ]; then
    echo "  - airflow-db-password"
fi
echo ""
echo "View secrets:"
echo "  gcloud secrets list --project=${PROJECT_ID}"
echo ""
echo "Access a secret:"
echo "  gcloud secrets versions access latest --secret=airflow-fernet-key --project=${PROJECT_ID}"
echo ""
echo "Grant access to a service account:"
echo "  gcloud secrets add-iam-policy-binding SECRET_NAME \\"
echo "    --member='serviceAccount:SA_EMAIL' \\"
echo "    --role='roles/secretmanager.secretAccessor' \\"
echo "    --project=${PROJECT_ID}"
echo ""
echo "⚠️  Next steps:"
echo "  1. Install External Secrets Operator (see above)"
echo "  2. Create SecretStore and ExternalSecret resources"
echo "  3. Update Helm values to reference the external secrets"
echo "  4. Deploy/upgrade Airflow"
echo "================================================"
