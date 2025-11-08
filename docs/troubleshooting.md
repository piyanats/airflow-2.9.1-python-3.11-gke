# Troubleshooting Guide

This guide covers common issues and their solutions for the Airflow deployment on GKE.

## Table of Contents

- [Docker Build Issues](#docker-build-issues)
- [Local Development Issues](#local-development-issues)
- [GKE Deployment Issues](#gke-deployment-issues)
- [Database Connection Issues](#database-connection-issues)
- [GitSync Issues](#gitsync-issues)
- [Workload Identity Issues](#workload-identity-issues)
- [Performance Issues](#performance-issues)
- [DAG Issues](#dag-issues)

---

## Docker Build Issues

### Issue: Docker build fails at uv installation

**Symptoms:**
```
ERROR: failed to solve: process "/bin/sh -c curl -LsSf https://astral.sh/uv/install.sh | sh" did not complete successfully
```

**Solution:**
```bash
# Ensure curl is installed
docker build --no-cache -t airflow-custom:latest ./docker

# If behind a proxy, set proxy variables
docker build --build-arg HTTP_PROXY=http://proxy:port \
  --build-arg HTTPS_PROXY=http://proxy:port \
  -t airflow-custom:latest ./docker
```

---

### Issue: Python package installation fails

**Symptoms:**
```
ERROR: Failed building wheel for package-name
```

**Solution:**
```bash
# Add missing system dependencies to Dockerfile
RUN apt-get update && apt-get install -y \
    python3-dev \
    libpq-dev \
    build-essential

# Clean build without cache
docker build --no-cache -t airflow-custom:latest ./docker
```

---

### Issue: Permission denied errors during build

**Symptoms:**
```
ERROR: permission denied while trying to connect to the Docker daemon socket
```

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo
sudo docker build -t airflow-custom:latest ./docker
```

---

## Local Development Issues

### Issue: Docker Compose fails to start

**Symptoms:**
```
ERROR: for postgres  Cannot start service postgres: driver failed
```

**Solution:**
```bash
# Stop all containers
docker-compose down -v

# Remove old volumes
docker volume prune

# Restart
docker-compose up -d

# Check logs
docker-compose logs -f
```

---

### Issue: Webserver returns 500 error

**Symptoms:**
```
Internal Server Error
```

**Solution:**
```bash
# Check webserver logs
docker-compose logs webserver

# Common causes:
# 1. Database not initialized
docker-compose run --rm airflow-init

# 2. Missing Fernet key
# Check .env file for AIRFLOW__CORE__FERNET_KEY

# 3. Wrong permissions
chmod -R 777 logs/ dags/ plugins/
```

---

### Issue: DAGs not appearing in UI

**Symptoms:**
- Empty DAG list in Airflow UI

**Solution:**
```bash
# Verify DAGs directory is mounted
docker-compose exec webserver ls -la /opt/airflow/dags

# Check for Python errors in DAGs
docker-compose exec scheduler airflow dags list

# Check scheduler logs
docker-compose logs scheduler | grep ERROR

# Trigger DAG parsing
docker-compose exec scheduler airflow dags reserialize
```

---

## GKE Deployment Issues

### Issue: Pods stuck in Pending

**Symptoms:**
```
kubectl get pods
NAME                        READY   STATUS    RESTARTS   AGE
airflow-scheduler-0         0/1     Pending   0          5m
```

**Solution:**
```bash
# Check pod events
kubectl describe pod airflow-scheduler-0 -n airflow-prod

# Common causes:
# 1. Insufficient resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# 2. Node selector mismatch
kubectl get nodes --show-labels

# 3. PVC not bound
kubectl get pvc -n airflow-prod

# Scale nodes if needed
gcloud container clusters resize airflow-cluster \
  --num-nodes=5 \
  --region=us-central1
```

---

### Issue: Pods in CrashLoopBackOff

**Symptoms:**
```
NAME                        READY   STATUS             RESTARTS   AGE
airflow-scheduler-0         0/1     CrashLoopBackOff   5          5m
```

**Solution:**
```bash
# Check pod logs
kubectl logs airflow-scheduler-0 -n airflow-prod

# Check previous logs
kubectl logs airflow-scheduler-0 -n airflow-prod --previous

# Describe pod for events
kubectl describe pod airflow-scheduler-0 -n airflow-prod

# Common causes:
# 1. Database connection failed - check connection string
# 2. Missing secrets - verify secrets exist
# 3. Image pull failed - check image name and credentials

# Verify secrets
kubectl get secrets -n airflow-prod
kubectl describe secret airflow-fernet-key -n airflow-prod
```

---

### Issue: Helm install fails

**Symptoms:**
```
Error: INSTALLATION FAILED: timed out waiting for the condition
```

**Solution:**
```bash
# Increase timeout
helm install airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --timeout 20m

# Debug mode
helm install airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml \
  --debug \
  --dry-run

# Check Helm status
helm status airflow -n airflow-prod

# Uninstall and retry
helm uninstall airflow -n airflow-prod
helm install airflow apache-airflow/airflow \
  --namespace airflow-prod \
  --values helm-chart/values-production.yaml
```

---

## Database Connection Issues

### Issue: Cannot connect to PostgreSQL

**Symptoms:**
```
sqlalchemy.exc.OperationalError: could not connect to server
```

**Solution:**
```bash
# For Cloud SQL:
# 1. Verify private IP
gcloud sql instances describe airflow-db \
  --format="value(ipAddresses[0].ipAddress)"

# 2. Check connectivity from pod
kubectl run -it --rm debug \
  --image=postgres:14 \
  --restart=Never \
  -n airflow-prod -- \
  psql -h CLOUDSQL_IP -U airflow -d airflow

# 3. Verify Workload Identity for Cloud SQL
kubectl describe sa airflow-sa -n airflow-prod | grep Annotations

# 4. Check secret
kubectl get secret airflow-metadata-secret -n airflow-prod -o yaml
```

---

### Issue: Database connection pool exhausted

**Symptoms:**
```
QueuePool limit of size X overflow Y reached, connection timed out
```

**Solution:**
```yaml
# Update Helm values for PgBouncer
pgbouncer:
  enabled: true
  maxClientConn: 200
  maxDbConn: 30  # Increase this

# Or increase Cloud SQL connections
gcloud sql instances patch airflow-db \
  --database-flags max_connections=300
```

---

## GitSync Issues

### Issue: GitSync fails with authentication error

**Symptoms:**
```
Permission denied (publickey)
```

**Solution:**
```bash
# Verify SSH secret exists
kubectl get secret airflow-ssh-secret -n airflow-prod

# Check secret content
kubectl get secret airflow-ssh-secret -n airflow-prod \
  -o jsonpath='{.data.gitSshKey}' | base64 -d | head -n 1

# Recreate secret with correct key
kubectl delete secret airflow-ssh-secret -n airflow-prod
kubectl create secret generic airflow-ssh-secret \
  --from-file=gitSshKey=~/.ssh/airflow-git-sync \
  -n airflow-prod

# Verify public key is added to Git repository
cat ~/.ssh/airflow-git-sync.pub
```

---

### Issue: GitSync not pulling latest DAGs

**Symptoms:**
- DAG changes not reflected in UI

**Solution:**
```bash
# Check git-sync logs
kubectl logs deployment/airflow-scheduler \
  -c git-sync \
  -n airflow-prod \
  --tail=50

# Verify sync interval
kubectl get deployment airflow-scheduler -n airflow-prod -o yaml | grep wait

# Force scheduler restart
kubectl rollout restart deployment/airflow-scheduler -n airflow-prod

# Check DAGs directory
kubectl exec deployment/airflow-scheduler -n airflow-prod -- \
  ls -la /opt/airflow/dags
```

---

## Workload Identity Issues

### Issue: GCS operations fail with permission denied

**Symptoms:**
```
google.auth.exceptions.DefaultCredentialsError
```

**Solution:**
```bash
# Verify Workload Identity annotation
kubectl describe sa airflow-sa -n airflow-prod

# Expected annotation:
# iam.gke.io/gcp-service-account: airflow-gke@PROJECT_ID.iam.gserviceaccount.com

# Verify IAM binding
gcloud iam service-accounts get-iam-policy \
  airflow-gke@PROJECT_ID.iam.gserviceaccount.com

# Re-create binding if missing
gcloud iam service-accounts add-iam-policy-binding \
  airflow-gke@PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:PROJECT_ID.svc.id.goog[airflow-prod/airflow-sa]"

# Test from pod
kubectl run -it --rm test \
  --image=google/cloud-sdk:slim \
  --serviceaccount=airflow-sa \
  -n airflow-prod -- \
  gcloud auth list
```

---

## Performance Issues

### Issue: Slow DAG parsing

**Symptoms:**
- DAGs take long time to appear
- High scheduler CPU usage

**Solution:**
```yaml
# Increase parser processes in Helm values
config:
  scheduler:
    parsing_processes: 8  # Increase from 4
    min_file_process_interval: 90  # Increase interval

# Reduce DAG complexity
# - Avoid dynamic DAG generation if possible
# - Use fewer tasks per DAG
# - Optimize imports
```

---

### Issue: Task execution delays

**Symptoms:**
- Long time between task scheduling and execution

**Solution:**
```yaml
# Increase scheduler resources
scheduler:
  resources:
    limits:
      cpu: 4000m
      memory: 8Gi

# Increase parallelism
config:
  core:
    parallelism: 128
    max_active_tasks_per_dag: 64
```

---

### Issue: High memory usage

**Symptoms:**
- Pods getting OOMKilled

**Solution:**
```yaml
# Increase memory limits
webserver:
  resources:
    limits:
      memory: 8Gi

# Enable PgBouncer to reduce connections
pgbouncer:
  enabled: true
  maxDbConn: 20

# Check for memory leaks in DAGs
# - Avoid loading large datasets in DAG code
# - Use XCom sparingly
# - Clean up temporary files
```

---

## DAG Issues

### Issue: DAG import errors

**Symptoms:**
```
Broken DAG: [/opt/airflow/dags/my_dag.py] ModuleNotFoundError
```

**Solution:**
```bash
# Check scheduler logs
kubectl logs deployment/airflow-scheduler -n airflow-prod | grep ERROR

# Install missing package
# Add to docker/requirements.txt and rebuild image

# Check Python syntax
python -m py_compile dags/my_dag.py

# Test DAG locally
docker-compose exec scheduler airflow dags test my_dag 2024-01-01
```

---

### Issue: Tasks fail with timeout

**Symptoms:**
```
Task exceeded maximum timeout of 300 seconds
```

**Solution:**
```python
# Increase task timeout in DAG
my_task = PythonOperator(
    task_id='my_task',
    execution_timeout=timedelta(minutes=30),  # Increase
    python_callable=my_function,
)

# Or set default in config
config:
  core:
    default_task_execution_timeout: 1800  # 30 minutes
```

---

## Quick Diagnostic Commands

### Check All Components

```bash
# Pods status
kubectl get pods -n airflow-prod

# Services
kubectl get svc -n airflow-prod

# Ingress
kubectl get ingress -n airflow-prod

# Secrets
kubectl get secrets -n airflow-prod

# ConfigMaps
kubectl get cm -n airflow-prod

# Events
kubectl get events -n airflow-prod --sort-by='.lastTimestamp'
```

---

### Get Logs

```bash
# Scheduler
kubectl logs -l component=scheduler -n airflow-prod --tail=100

# Webserver
kubectl logs -l component=webserver -n airflow-prod --tail=100

# Triggerer
kubectl logs -l component=triggerer -n airflow-prod --tail=100

# Worker (if any)
kubectl logs -l component=worker -n airflow-prod --tail=100

# GitSync
kubectl logs deployment/airflow-scheduler -c git-sync -n airflow-prod
```

---

### Database Checks

```bash
# Connect to database
kubectl run -it --rm psql \
  --image=postgres:14 \
  --restart=Never \
  -n airflow-prod -- \
  psql postgresql://airflow:PASSWORD@CLOUDSQL_IP/airflow

# Check active connections
SELECT count(*) FROM pg_stat_activity;

# Check locks
SELECT * FROM pg_locks;
```

---

### Resource Usage

```bash
# Pod resource usage
kubectl top pods -n airflow-prod

# Node resource usage
kubectl top nodes

# Describe node
kubectl describe node NODE_NAME | grep -A 5 "Allocated resources"
```

---

## Getting Help

If you're still stuck:

1. **Check logs** - Most issues show up in logs
2. **Search documentation** - Check official Airflow docs
3. **Community** - Ask on Apache Airflow Slack
4. **GitHub** - Check Airflow GitHub issues
5. **GCP Support** - For infrastructure issues

---

## Useful Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Airflow Helm Chart](https://airflow.apache.org/docs/helm-chart/)
- [GKE Troubleshooting](https://cloud.google.com/kubernetes-engine/docs/troubleshooting)
- [Cloud SQL Troubleshooting](https://cloud.google.com/sql/docs/postgres/troubleshooting)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
