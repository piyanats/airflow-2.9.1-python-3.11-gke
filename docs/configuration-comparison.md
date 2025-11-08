# Configuration Comparison: Development vs Production

This document compares the configuration differences between development (values.yaml) and production (values-production.yaml) deployments.

## Overview

| Aspect | Development | Production |
|--------|-------------|------------|
| **Purpose** | Local testing, development | Production workloads |
| **Availability** | Single instance | High availability |
| **Resource Usage** | Minimal | Optimized for performance |
| **Security** | Basic | Hardened |
| **Monitoring** | Basic logs | Full observability |
| **Cost** | Low | Higher (optimized for reliability) |

## Detailed Comparison

### Executor Configuration

| Configuration | Development | Production |
|---------------|-------------|------------|
| Executor | LocalExecutor (docker-compose) or KubernetesExecutor | KubernetesExecutor |
| Reason | Simplicity, local testing | Scalability, isolation, resource management |

### High Availability

| Component | Development | Production |
|-----------|-------------|------------|
| **Webserver** | 1 replica | 2+ replicas with anti-affinity |
| **Scheduler** | 1 replica | 2 replicas with leader election |
| **Triggerer** | 1 replica | 2 replicas with anti-affinity |
| **PgBouncer** | Disabled | Enabled (2 replicas) |
| **PodDisruptionBudget** | Not configured | Enabled for all components |

### Resource Allocation

#### Webserver

| Resource | Development | Production |
|----------|-------------|------------|
| CPU Request | 500m | 1000m |
| CPU Limit | 1000m | 2000m |
| Memory Request | 1Gi | 2Gi |
| Memory Limit | 2Gi | 4Gi |

#### Scheduler

| Resource | Development | Production |
|----------|-------------|------------|
| CPU Request | 500m | 1000m |
| CPU Limit | 1000m | 2000m |
| Memory Request | 1Gi | 2Gi |
| Memory Limit | 2Gi | 4Gi |

#### Workers

| Resource | Development | Production |
|----------|-------------|------------|
| CPU Request | 500m | 500m |
| CPU Limit | 1000m | 2000m |
| Memory Request | 1Gi | 1Gi |
| Memory Limit | 2Gi | 4Gi |

### Database Configuration

| Aspect | Development | Production |
|--------|-------------|------------|
| Database | PostgreSQL in Docker | Cloud SQL (Regional, HA) |
| Connection Pooling | Direct connection | PgBouncer enabled |
| Max Connections | Default (100) | 200 |
| SSL Mode | Disable | Require |
| Backup | None | Automated daily backups |
| High Availability | No | Regional (multi-zone) |

### Logging

| Aspect | Development | Production |
|--------|-------------|------------|
| Local Logs | Enabled | Enabled |
| Remote Logs (GCS) | Optional | Mandatory |
| Log Level | INFO | INFO |
| Log Retention | Not configured | 15 days local, 90 days GCS |
| Log Groomer | Disabled | Enabled |

### Security

| Feature | Development | Production |
|---------|-------------|------------|
| Secrets Management | Plain text in values.yaml | Kubernetes Secrets or Secret Manager |
| Workload Identity | Not required | Mandatory |
| Network Policies | Disabled | Enabled |
| SSL/TLS | Not required | Required everywhere |
| RBAC | Minimal | Strict |
| Security Context | Default | runAsNonRoot, specific UID |
| Pod Security Standards | Not enforced | Enforced |
| Ingress | LoadBalancer or None | Ingress with Cloud Armor |
| Certificate | Self-signed or none | Google-managed or Let's Encrypt |

### Monitoring & Observability

| Feature | Development | Production |
|---------|-------------|------------|
| StatsD | Disabled | Enabled |
| Prometheus Metrics | Not configured | Configured with exporters |
| Service Monitor | Disabled | Enabled (if using Prometheus Operator) |
| Cloud Monitoring | Not configured | Enabled |
| Alerting | None | Configured for critical metrics |
| Audit Logging | Disabled | Enabled |

### Airflow Configuration

#### Core Settings

| Setting | Development | Production |
|---------|-------------|------------|
| `load_examples` | true (helpful for testing) | false |
| `parallelism` | 32 | 64 |
| `max_active_tasks_per_dag` | 16 | 32 |
| `max_active_runs_per_dag` | 16 | 16 |
| `dag_file_processor_timeout` | 50s | 120s |

#### Scheduler Settings

| Setting | Development | Production |
|---------|-------------|------------|
| `parsing_processes` | 2 | 4 |
| `min_file_process_interval` | 30s | 60s |
| `dag_dir_list_interval` | 300s | 300s |
| `scheduler_heartbeat_sec` | 5s | 5s |

#### Webserver Settings

| Setting | Development | Production |
|---------|-------------|------------|
| `expose_config` | true | false (security) |
| `expose_hostname` | true | false (security) |
| `expose_stacktrace` | true | false (security) |
| `enable_proxy_fix` | false | true (behind LB) |
| `web_server_worker_timeout` | 120s | 300s |

### DAG Deployment

| Aspect | Development | Production |
|--------|-------------|------------|
| Method | Local mount or GitSync | GitSync only |
| Git Polling | 60s | 60s |
| SSH Key | Optional | Mandatory |
| Git Depth | 1 | 1 |
| Subpath | "dags" | "dags" |

### Ingress & Networking

| Feature | Development | Production |
|---------|-------------|------------|
| Service Type | LoadBalancer | ClusterIP |
| Ingress | Disabled | Enabled |
| Static IP | No | Yes (reserved) |
| SSL Certificate | None | Google-managed |
| Cloud Armor | No | Yes (DDoS protection) |
| Domain | localhost:8080 | airflow.example.com |

### Autoscaling

| Component | Development | Production |
|-----------|-------------|------------|
| GKE Nodes | Manual | Cluster autoscaler enabled |
| HPA (Webserver) | Disabled | Can be enabled (optional) |
| HPA (Workers) | N/A | Handled by KubernetesExecutor |

### Cost Optimization

| Aspect | Development | Production |
|--------|-------------|------------|
| Node Type | n1-standard-2 | n1-standard-4 |
| Min Nodes | 1 | 3 |
| Max Nodes | 3 | 10 |
| Preemptible/Spot | Can use | Not recommended for core components |
| Resource Requests | Lower | Properly sized |
| Autoscaling | Limited | Enabled |

### Maintenance

| Aspect | Development | Production |
|--------|-------------|------------|
| Update Strategy | Immediate | Rolling update with PDB |
| Backup Strategy | None | Automated backups |
| Disaster Recovery | None | Documented and tested |
| Upgrade Process | Direct | Staged (staging → production) |
| Testing | Manual | Automated + manual |

## Migration from Development to Production

### Pre-Migration Checklist

- [ ] Review and understand all production configurations
- [ ] Provision production infrastructure (GKE, Cloud SQL, GCS)
- [ ] Set up monitoring and alerting
- [ ] Configure secrets securely
- [ ] Set up backup and disaster recovery
- [ ] Document runbooks and procedures
- [ ] Test in staging environment first

### Migration Steps

1. **Infrastructure**: Provision production GKE and Cloud SQL
2. **Secrets**: Migrate secrets to Kubernetes Secrets or Secret Manager
3. **Configuration**: Update values-production.yaml with production settings
4. **Testing**: Deploy to staging and run comprehensive tests
5. **Migration**: Deploy to production during maintenance window
6. **Validation**: Run verification script and functional tests
7. **Monitoring**: Verify all monitoring and alerting is working
8. **Documentation**: Update all documentation with production details

### Rollback Plan

If issues occur during migration:

1. Keep development environment running during migration
2. Have database backup before migration
3. Document rollback steps
4. Test rollback procedure in staging
5. Set a go/no-go decision point

## Configuration Selection Guide

### Use Development Configuration When:

- Local development and testing
- Learning Airflow
- Prototyping DAGs
- Resource-constrained environments
- Non-critical workloads

### Use Production Configuration When:

- Production workloads
- Business-critical DAGs
- Multi-team environments
- Compliance requirements
- High availability needed
- Scalability required

## Best Practices

### Development

1. Keep it simple and fast to iterate
2. Use docker-compose for local testing
3. Use LoadBalancer for quick access
4. Enable examples for learning
5. Use local PostgreSQL
6. Minimal resource allocation

### Production

1. Security first (secrets, RBAC, network policies)
2. High availability for all components
3. Proper resource allocation based on monitoring
4. Automated backups and disaster recovery
5. Comprehensive monitoring and alerting
6. Use Cloud SQL with regional HA
7. Enable PgBouncer for connection pooling
8. Use Google-managed certificates
9. Implement Cloud Armor for security
10. Regular security audits and updates

## Common Pitfalls to Avoid

### Development

- Running production workloads on development config
- Not testing with production-like data volumes
- Ignoring resource constraints

### Production

- Under-provisioning resources
- Not testing disaster recovery
- Ignoring security best practices
- Not monitoring properly
- Skipping staging environment
- Hard-coding secrets
- Not having runbooks
- Insufficient backup retention

## References

- [Apache Airflow Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Cloud SQL Best Practices](https://cloud.google.com/sql/docs/postgres/best-practices)
- [Production Deployment Guide](../PRODUCTION-DEPLOYMENT.md)
