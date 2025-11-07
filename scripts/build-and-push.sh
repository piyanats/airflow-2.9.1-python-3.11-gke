#!/bin/bash

# Exit on error
set -e

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-your-gcp-project-id}"
IMAGE_NAME="airflow-custom"
IMAGE_TAG="${IMAGE_TAG:-2.9.1-python3.11}"
REGION="${GCR_REGION:-us}"

# Full image path
IMAGE_PATH="${REGION}.gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "================================================"
echo "Building Custom Airflow Docker Image"
echo "================================================"
echo "Project ID: ${PROJECT_ID}"
echo "Image Name: ${IMAGE_NAME}"
echo "Image Tag: ${IMAGE_TAG}"
echo "Full Path: ${IMAGE_PATH}"
echo "================================================"

# Prompt for confirmation
read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Configure Docker to use gcloud as a credential helper
echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}.gcr.io --quiet

# Build the Docker image
echo "Building Docker image..."
cd "$(dirname "$0")/../docker"
docker build -t ${IMAGE_PATH} .

# Tag as latest
docker tag ${IMAGE_PATH} ${REGION}.gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest

# Push the image to GCR
echo "Pushing image to GCR..."
docker push ${IMAGE_PATH}
docker push ${REGION}.gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest

echo "================================================"
echo "✅ Image successfully pushed to GCR!"
echo "Image: ${IMAGE_PATH}"
echo "Latest: ${REGION}.gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest"
echo "================================================"
echo ""
echo "Update your Helm values.yaml with:"
echo "  images:"
echo "    airflow:"
echo "      repository: ${REGION}.gcr.io/${PROJECT_ID}/${IMAGE_NAME}"
echo "      tag: ${IMAGE_TAG}"
