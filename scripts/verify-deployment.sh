#!/bin/bash

# Script to verify Airflow deployment on GKE
set -e

NAMESPACE="${K8S_NAMESPACE:-default}"

echo "================================================"
echo "Verifying Airflow Deployment on GKE"
echo "================================================"
echo "Namespace: ${NAMESPACE}"
echo ""

# Check if kubectl is configured
echo "1. Checking kubectl configuration..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ kubectl is properly configured"
    kubectl cluster-info | head -n 1
else
    echo "❌ kubectl is not configured or cannot connect to cluster"
    exit 1
fi
echo ""

# Check namespace
echo "2. Checking namespace..."
if kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "✅ Namespace '${NAMESPACE}' exists"
else
    echo "❌ Namespace '${NAMESPACE}' does not exist"
    exit 1
fi
echo ""

# Check service accounts
echo "3. Checking service accounts..."
if kubectl get serviceaccount airflow-sa -n ${NAMESPACE} &> /dev/null; then
    echo "✅ Service account 'airflow-sa' exists"
    echo "   Annotations:"
    kubectl get serviceaccount airflow-sa -n ${NAMESPACE} -o jsonpath='{.metadata.annotations}' | jq '.'
else
    echo "⚠️  Service account 'airflow-sa' not found"
fi
echo ""

# Check secrets
echo "4. Checking secrets..."
if kubectl get secret airflow-fernet-key -n ${NAMESPACE} &> /dev/null; then
    echo "✅ Secret 'airflow-fernet-key' exists"
else
    echo "⚠️  Secret 'airflow-fernet-key' not found"
fi

if kubectl get secret airflow-ssh-secret -n ${NAMESPACE} &> /dev/null; then
    echo "✅ Secret 'airflow-ssh-secret' exists"
else
    echo "⚠️  Secret 'airflow-ssh-secret' not found (required for GitSync)"
fi
echo ""

# Check Helm release
echo "5. Checking Helm release..."
if helm list -n ${NAMESPACE} | grep -q airflow; then
    echo "✅ Airflow Helm release found"
    helm list -n ${NAMESPACE} | grep airflow
else
    echo "❌ Airflow Helm release not found"
    echo "   Install with: helm install airflow apache-airflow/airflow --namespace ${NAMESPACE} --values helm-chart/values.yaml"
    exit 1
fi
echo ""

# Check pods
echo "6. Checking pods..."
echo "Pod status:"
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=airflow

echo ""
echo "Pod details:"
TOTAL_PODS=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=airflow --no-headers | wc -l)
RUNNING_PODS=$(kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/name=airflow --no-headers | grep -c Running || echo "0")

echo "Total Airflow pods: ${TOTAL_PODS}"
echo "Running pods: ${RUNNING_PODS}"

if [ "${RUNNING_PODS}" -eq "${TOTAL_PODS}" ] && [ "${TOTAL_PODS}" -gt 0 ]; then
    echo "✅ All Airflow pods are running"
else
    echo "⚠️  Not all pods are running. Check pod status above."
    echo ""
    echo "To debug, run:"
    echo "  kubectl describe pod <pod-name> -n ${NAMESPACE}"
    echo "  kubectl logs <pod-name> -n ${NAMESPACE}"
fi
echo ""

# Check services
echo "7. Checking services..."
if kubectl get svc airflow-webserver -n ${NAMESPACE} &> /dev/null; then
    echo "✅ Webserver service exists"
    kubectl get svc airflow-webserver -n ${NAMESPACE}
else
    echo "❌ Webserver service not found"
fi
echo ""

# Check webserver health
echo "8. Checking webserver health..."
WEBSERVER_POD=$(kubectl get pods -n ${NAMESPACE} -l component=webserver --no-headers -o custom-columns=":metadata.name" | head -n 1)

if [ -n "${WEBSERVER_POD}" ]; then
    echo "Webserver pod: ${WEBSERVER_POD}"
    if kubectl exec ${WEBSERVER_POD} -n ${NAMESPACE} -- curl -f http://localhost:8080/health &> /dev/null; then
        echo "✅ Webserver health check passed"
    else
        echo "⚠️  Webserver health check failed"
    fi
else
    echo "⚠️  No webserver pod found"
fi
echo ""

# Check scheduler health
echo "9. Checking scheduler health..."
SCHEDULER_POD=$(kubectl get pods -n ${NAMESPACE} -l component=scheduler --no-headers -o custom-columns=":metadata.name" | head -n 1)

if [ -n "${SCHEDULER_POD}" ]; then
    echo "Scheduler pod: ${SCHEDULER_POD}"
    if kubectl exec ${SCHEDULER_POD} -n ${NAMESPACE} -- curl -f http://localhost:8974/health &> /dev/null; then
        echo "✅ Scheduler health check passed"
    else
        echo "⚠️  Scheduler health check failed"
    fi
else
    echo "⚠️  No scheduler pod found"
fi
echo ""

# Check GitSync (if enabled)
echo "10. Checking GitSync..."
if kubectl logs ${SCHEDULER_POD} -c git-sync -n ${NAMESPACE} --tail=5 &> /dev/null; then
    echo "✅ GitSync container found"
    echo "Recent GitSync logs:"
    kubectl logs ${SCHEDULER_POD} -c git-sync -n ${NAMESPACE} --tail=5
else
    echo "⚠️  GitSync container not found or not configured"
fi
echo ""

# Check GCS connectivity
echo "11. Checking GCS connectivity (Workload Identity)..."
if [ -n "${SCHEDULER_POD}" ]; then
    if kubectl exec ${SCHEDULER_POD} -n ${NAMESPACE} -- python3 -c "from google.cloud import storage; client = storage.Client(); print(f'Project: {client.project}')" &> /dev/null; then
        echo "✅ GCS connectivity successful (Workload Identity working)"
    else
        echo "⚠️  GCS connectivity failed - check Workload Identity configuration"
    fi
else
    echo "⚠️  Cannot check GCS connectivity - no scheduler pod"
fi
echo ""

# Summary
echo "================================================"
echo "Verification Summary"
echo "================================================"
echo "If all checks passed, your Airflow deployment is ready!"
echo ""
echo "To access Airflow UI:"
echo "  kubectl port-forward svc/airflow-webserver 8080:8080 -n ${NAMESPACE}"
echo "  Then open: http://localhost:8080"
echo ""
echo "To view logs:"
echo "  kubectl logs -f <pod-name> -n ${NAMESPACE}"
echo ""
echo "To check DAGs:"
echo "  kubectl exec ${SCHEDULER_POD} -n ${NAMESPACE} -- airflow dags list"
echo "================================================"
