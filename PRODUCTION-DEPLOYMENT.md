# Production Deployment Guide for Apache Airflow on GKE

This guide provides a comprehensive checklist and best practices for deploying Apache Airflow 2.9.1 in a production environment on Google Kubernetes Engine (GKE).

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Infrastructure Setup](#infrastructure-setup)
3. [Security Configuration](#security-configuration)
4. [Deployment Steps](#deployment-steps)
5. [Post-Deployment Validation](#post-deployment-validation)
6. [Monitoring and Observability](#monitoring-and-observability)
7. [Backup and Disaster Recovery](#backup-and-disaster-recovery)
8. [Maintenance and Operations](#maintenance-and-operations)

## Pre-Deployment Checklist

### Infrastructure Requirements

- [ ] GKE cluster with Workload Identity enabled
- [ ] Dedicated node pool for Airflow workloads (recommended)
- [ ] Minimum 3 nodes for high availability
- [ ] Node machine type: n1-standard-4 or better
- [ ] Network policies enabled on GKE cluster
- [ ] Cloud SQL PostgreSQL instance (db-custom-2-7680 or larger)
- [ ] GCS bucket for logs with versioning enabled
- [ ] Static external IP reserved for Ingress
- [ ] SSL certificate provisioned (Google-managed or Let's Encrypt)

### Network and DNS

- [ ] VPC with private IP ranges configured
- [ ] Cloud SQL private IP enabled
- [ ] DNS A record pointing to Ingress IP
- [ ] Firewall rules configured
- [ ] Cloud Armor security policy created (optional but recommended)

### Service Accounts and IAM

- [ ] Google Service Account created for Airflow
- [ ] IAM roles granted:
  - [ ] Storage Admin (for GCS logs)
  - [ ] Cloud SQL Client
  - [ ] BigQuery Data Editor (if using BigQuery)
  - [ ] Service Account User
- [ ] Workload Identity binding configured
- [ ] Kubernetes Service Account created and annotated

## Infrastructure Setup

### 1. Create GKE Cluster

```bash
# Set variables
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export CLUSTER_NAME="airflow-prod"

# Create GKE cluster
gcloud container clusters create ${CLUSTER_NAME} \
  --region ${REGION} \
  --workload-pool=${PROJECT_ID}.svc.id.goog \
  --enable-ip-alias \
  --enable-network-policy \
  --enable-autorepair \
  --enable-autoupgrade \
  --maintenance-window-start "2024-01-01T03:00:00Z" \
  --maintenance-window-duration "4h" \
  --num-nodes 1 \
  --min-nodes 3 \
  --max-nodes 10 \
  --enable-autoscaling \
  --machine-type n1-standard-4 \
  --disk-type pd-ssd \
  --disk-size 100 \
  --enable-stackdriver-kubernetes \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --release-channel regular \
  --labels environment=production,app=airflow
```

### 2. Create Dedicated Node Pool for Airflow

```bash
gcloud container node-pools create airflow-pool \
  --cluster ${CLUSTER_NAME} \
  --region ${REGION} \
  --machine-type n1-standard-4 \
  --num-nodes 3 \
  --min-nodes 3 \
  --max-nodes 10 \
  --enable-autoscaling \
  --enable-autorepair \
  --enable-autoupgrade \
  --node-labels workload-type=airflow \
  --node-taints workload-type=airflow:NoSchedule \
  --disk-type pd-ssd \
  --disk-size 100
```

### 3. Create Cloud SQL Instance

```bash
# Create Cloud SQL instance
gcloud sql instances create airflow-db \
  --database-version=POSTGRES_14 \
  --tier=db-custom-4-15360 \
  --region=${REGION} \
  --network=default \
  --no-assign-ip \
  --enable-bin-log \
  --backup-start-time=02:00 \
  --retained-backups-count=30 \
  --retained-transaction-log-days=7 \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=3 \
  --maintenance-release-channel=production \
  --availability-type=REGIONAL \
  --database-flags max_connections=200

# Create database and user
gcloud sql databases create airflow --instance=airflow-db

# Create user (save the password securely)
gcloud sql users create airflow \
  --instance=airflow-db \
  --password=$(openssl rand -base64 32)

# Get private IP
gcloud sql instances describe airflow-db --format="value(ipAddresses[0].ipAddress)"
```

### 4. Create GCS Bucket

```bash
export BUCKET_NAME="${PROJECT_ID}-airflow-logs"

# Create bucket
gsutil mb -p ${PROJECT_ID} -c STANDARD -l ${REGION} gs://${BUCKET_NAME}

# Enable versioning
gsutil versioning set on gs://${BUCKET_NAME}

# Set lifecycle policy (delete logs older than 90 days)
cat > lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 90}
      }
    ]
  }
}
EOF

gsutil lifecycle set lifecycle.json gs://${BUCKET_NAME}
```

### 5. Reserve Static IP

```bash
gcloud compute addresses create airflow-prod-ip \
  --global \
  --ip-version IPV4

# Get the IP address
gcloud compute addresses describe airflow-prod-ip --global --format="value(address)"
```

## Security Configuration

### 1. Run Setup Script

```bash
# Set environment variables
export GCP_PROJECT_ID="${PROJECT_ID}"
export GCP_REGION="${REGION}"
export GKE_CLUSTER_NAME="${CLUSTER_NAME}"
export K8S_NAMESPACE="airflow-prod"
export GCS_BUCKET_NAME="${BUCKET_NAME}"

# Run setup script
./scripts/setup-gke.sh
```

### 2. Create Secrets

```bash
# Set database credentials
export DB_HOST="10.x.x.x"  # Cloud SQL private IP
export DB_PASSWORD="your-secure-password"
export DB_USER="airflow"
export DB_NAME="airflow"
export K8S_NAMESPACE="airflow-prod"

# Create secrets
./scripts/create-secrets.sh
```

### 3. Create SSH Key for GitSync

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "airflow-gitsync" -f ~/.ssh/airflow-git-sync -N ""

# Display public key
cat ~/.ssh/airflow-git-sync.pub

# Add to GitHub/GitLab as deploy key

# Create Kubernetes secret
kubectl create secret generic airflow-ssh-secret \
  --from-file=gitSshKey=~/.ssh/airflow-git-sync \
  --namespace=airflow-prod
```

### 4. Configure Network Policies

```bash
# Apply network policies
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: airflow-network-policy
  namespace: airflow-prod
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: airflow
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: airflow
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
  egress:
  - to:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: airflow
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS (for GCS, etc.)
EOF
```

### 5. Create Managed Certificate

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: airflow-cert
  namespace: airflow-prod
spec:
  domains:
    - airflow.example.com
EOF
```

### 6. Configure Cloud Armor (Optional)

```bash
# Create security policy
gcloud compute security-policies create airflow-armor-policy \
  --description "Security policy for Airflow"

# Add rate limiting rule
gcloud compute security-policies rules create 1000 \
  --security-policy airflow-armor-policy \
  --expression "true" \
  --action "rate-based-ban" \
  --rate-limit-threshold-count 1000 \
  --rate-limit-threshold-interval-sec 60 \
  --ban-duration-sec 600

# Block common attacks
gcloud compute security-policies rules create 2000 \
  --security-policy airflow-armor-policy \
  --expression "evaluatePreconfiguredExpr('sqli-stable')" \
  --action "deny-403"

gcloud compute security-policies rules create 3000 \
  --security-policy airflow-armor-policy \
  --expression "evaluatePreconfiguredExpr('xss-stable')" \
  --action "deny-403"
```

## Deployment Steps

### 1. Update Production Values

Edit `helm-chart/values-production.yaml` and update the following:

- [ ] Replace `YOUR-PROJECT-ID` with actual project ID
- [ ] Replace `YOUR-GCS-BUCKET` with actual bucket name
- [ ] Replace `YOUR-CLOUDSQL-PRIVATE-IP` with Cloud SQL IP
- [ ] Update Git repository URL
- [ ] Update domain name
- [ ] Review and adjust resource limits
- [ ] Configure SMTP settings if needed

### 2. Build and Push Docker Image

```bash
# Set environment variables
export GCP_PROJECT_ID="${PROJECT_ID}"
export IMAGE_TAG="2.9.1-python3.11"
export GCR_REGION="us"

# Build and push
./scripts/build-and-push.sh
```

### 3. Add Helm Repository

```bash
helm repo add apache-airflow https://airflow.apache.org
helm repo update
```

### 4. Validate Helm Chart

```bash
# Dry run to validate
helm install airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --dry-run \
  --debug
```

### 5. Install Airflow

```bash
# Install Airflow
helm install airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --timeout 15m \
  --wait

# Or upgrade if already installed
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --timeout 15m \
  --wait
```

## Post-Deployment Validation

### 1. Run Verification Script

```bash
export K8S_NAMESPACE="airflow-prod"
./scripts/verify-deployment.sh
```

### 2. Manual Verification Checklist

- [ ] All pods are running: `kubectl get pods -n airflow-prod`
- [ ] Webserver is healthy: `kubectl logs -l component=webserver -n airflow-prod --tail=50`
- [ ] Scheduler is running: `kubectl logs -l component=scheduler -n airflow-prod --tail=50`
- [ ] Triggerer is running: `kubectl logs -l component=triggerer -n airflow-prod --tail=50`
- [ ] PgBouncer is running: `kubectl get pods -l component=pgbouncer -n airflow-prod`
- [ ] GitSync is syncing DAGs: Check git-sync container logs
- [ ] Database migrations completed: Check init job logs
- [ ] Ingress has IP assigned: `kubectl get ingress -n airflow-prod`
- [ ] SSL certificate is active: Check managed certificate status

### 3. Functional Tests

```bash
# Port forward to access UI
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow-prod

# Test login at http://localhost:8080

# Test DAG trigger
kubectl exec -it deployment/airflow-scheduler -n airflow-prod -- \
  airflow dags trigger example_dag

# Check task logs
kubectl exec -it deployment/airflow-scheduler -n airflow-prod -- \
  airflow tasks test example_dag print_hello 2024-01-01
```

### 4. Performance Tests

- [ ] Verify DAG parsing time is acceptable
- [ ] Check scheduler heartbeat interval
- [ ] Monitor task throughput
- [ ] Validate database connection pooling
- [ ] Check GCS log upload latency

## Monitoring and Observability

### 1. Set Up Cloud Monitoring

```bash
# Create monitoring dashboard
gcloud monitoring dashboards create --config-from-file=- <<EOF
{
  "displayName": "Airflow Production Monitoring",
  "dashboardFilters": [
    {
      "filterType": "RESOURCE_LABEL",
      "labelKey": "cluster_name",
      "stringValue": "${CLUSTER_NAME}"
    }
  ],
  "mosaicLayout": {
    "columns": 12,
    "tiles": []
  }
}
EOF
```

### 2. Set Up Alerts

Create alerts for:

- [ ] Pod restarts > 3 in 10 minutes
- [ ] CPU usage > 80% for 10 minutes
- [ ] Memory usage > 85% for 10 minutes
- [ ] Scheduler heartbeat stopped
- [ ] Database connection pool exhaustion
- [ ] Failed DAG runs
- [ ] Task failure rate > threshold

### 3. Enable Audit Logging

```bash
# Enable GKE audit logging
gcloud container clusters update ${CLUSTER_NAME} \
  --region ${REGION} \
  --enable-cloud-logging \
  --logging=SYSTEM,WORKLOAD \
  --enable-cloud-monitoring \
  --monitoring=SYSTEM
```

### 4. Prometheus Integration (Optional)

If using Prometheus Operator:

```bash
# Enable ServiceMonitor in values-production.yaml
# Then deploy Prometheus ServiceMonitor
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: airflow
  namespace: airflow-prod
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: airflow
  endpoints:
  - port: metrics
    interval: 30s
EOF
```

## Backup and Disaster Recovery

### 1. Database Backup Strategy

- [ ] Cloud SQL automated backups enabled (daily)
- [ ] Point-in-time recovery enabled
- [ ] Backup retention: 30 days minimum
- [ ] Test restore procedure documented

### 2. Configuration Backup

```bash
# Backup Helm values
cp helm-chart/values-production.yaml backups/values-$(date +%Y%m%d).yaml

# Backup Kubernetes secrets (encrypted)
kubectl get secrets -n airflow-prod -o yaml > backups/secrets-$(date +%Y%m%d).yaml.enc
# Encrypt the file before storing
```

### 3. DAG Backup

- [ ] DAGs are in Git repository
- [ ] Git repository has redundancy (GitHub/GitLab)
- [ ] Regular commits and tags

### 4. Disaster Recovery Plan

Document and test:

- [ ] Database restore procedure
- [ ] GKE cluster recreation
- [ ] Secret restoration
- [ ] Airflow redeployment
- [ ] RTO (Recovery Time Objective): Target < 4 hours
- [ ] RPO (Recovery Point Objective): Target < 1 hour

## Maintenance and Operations

### 1. Regular Maintenance Tasks

**Daily:**
- [ ] Monitor pod health and restarts
- [ ] Check DAG execution success rate
- [ ] Review failed tasks

**Weekly:**
- [ ] Review resource utilization
- [ ] Check database performance
- [ ] Review logs for errors
- [ ] Validate backup completion

**Monthly:**
- [ ] Update dependencies
- [ ] Review and optimize slow DAGs
- [ ] Capacity planning review
- [ ] Security audit

**Quarterly:**
- [ ] Rotate secrets and credentials
- [ ] Update Airflow version
- [ ] Disaster recovery drill
- [ ] Security vulnerability scan

### 2. Scaling Guidelines

**Scale up when:**
- CPU usage > 70% sustained
- Memory usage > 75% sustained
- Task queue depth increasing
- Scheduler lag increasing

**Scale down when:**
- CPU usage < 30% for 24 hours
- Memory usage < 40% for 24 hours
- Task queue consistently empty

### 3. Upgrade Procedure

```bash
# 1. Backup current deployment
helm get values airflow -n airflow-prod > backups/current-values.yaml

# 2. Update Helm repository
helm repo update

# 3. Check new version
helm search repo apache-airflow/airflow

# 4. Review changelog
# Visit: https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html

# 5. Test in staging environment first

# 6. Upgrade in production
helm upgrade airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --timeout 15m \
  --wait

# 7. Verify deployment
./scripts/verify-deployment.sh
```

### 4. Troubleshooting Common Issues

**Pod CrashLoopBackOff:**
```bash
kubectl describe pod <pod-name> -n airflow-prod
kubectl logs <pod-name> -n airflow-prod --previous
```

**Database connection issues:**
```bash
# Check PgBouncer logs
kubectl logs -l component=pgbouncer -n airflow-prod

# Test database connectivity
kubectl run -it --rm debug --image=postgres:14 --restart=Never -- \
  psql -h <CLOUDSQL-IP> -U airflow -d airflow
```

**GitSync not syncing:**
```bash
# Check git-sync logs
kubectl logs deployment/airflow-scheduler -c git-sync -n airflow-prod

# Verify SSH key
kubectl get secret airflow-ssh-secret -n airflow-prod -o yaml
```

**High memory usage:**
```bash
# Check metrics
kubectl top pods -n airflow-prod

# Adjust resources in values-production.yaml
```

## Security Best Practices

### Production Security Checklist

- [ ] All secrets stored in Kubernetes Secrets or Google Secret Manager
- [ ] SSL/TLS enabled for all connections
- [ ] Network policies enabled and tested
- [ ] Workload Identity used (no SA keys)
- [ ] RBAC properly configured
- [ ] Pod Security Standards enforced
- [ ] Audit logging enabled
- [ ] Regular security scans
- [ ] Minimal IAM permissions
- [ ] Private GKE cluster (optional but recommended)
- [ ] Cloud Armor enabled
- [ ] VPC Service Controls (for highly sensitive environments)

### Compliance Considerations

Depending on your industry:

- [ ] GDPR compliance (if handling EU data)
- [ ] HIPAA compliance (if handling health data)
- [ ] SOC 2 compliance
- [ ] PCI DSS compliance (if handling payment data)

## Support and Escalation

### Contact Information

- **Primary On-Call**: [contact-info]
- **Secondary On-Call**: [contact-info]
- **Manager**: [contact-info]
- **GCP Support**: [support-plan]

### Escalation Path

1. Check runbooks and documentation
2. Contact primary on-call
3. Escalate to secondary on-call
4. Involve GCP support for infrastructure issues
5. Page manager for critical incidents

## Additional Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)

---

**Last Updated**: [Date]
**Owner**: [Team/Individual]
**Review Frequency**: Quarterly
