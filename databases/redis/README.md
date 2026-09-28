# Redis High Availability Setup

This project provides Kubernetes-native high availability Redis setups, following the same patterns as the PostgreSQL HA setup. It includes three deployment options:

1. **Redis Single** - Single Redis instance with persistent storage
2. **Redis Sentinel** - Master-Slave replication with automatic failover using Redis Sentinel
3. **Redis Cluster** - Distributed Redis cluster with automatic sharding

## Prerequisites

- Kubernetes cluster (for development: minikube, kind, or Docker Desktop Kubernetes)
- `kubectl` configured to access your cluster
- `envsubst` command available (usually included in most OS distributions)

## Environment Configuration

First, configure your environment variables in `env.mk`:

```bash
NAMESPACE=browseterm

# Redis Configuration
REDIS_PASSWORD=test123
REDIS_MASTER_PASSWORD=master123
REDIS_SENTINEL_PASSWORD=sentinel123
REDIS_USER=redis

# Redis Data Dir
REDIS_DATA_DIR=/Users/namahshrestha/test/browseterm/redis_ha/data
```

## Deployment Options

### 1. Redis Single Instance

For development or testing purposes:

```bash
# Setup Redis single instance
make dev_redis_single_setup

# Teardown
make dev_redis_single_teardown
```

**Features:**
- Single Redis instance
- Persistent storage (preserves data across restarts)
- Password authentication
- AOF persistence enabled

**Connection:**
```bash
# Via kubectl exec
kubectl exec -it browseterm-redis -n browseterm -- redis-cli --user browseterm -a test123

# Via port-forward
kubectl port-forward service/browseterm-redis-service -n browseterm 6379:6379
redis-cli -h localhost -p 6379 --user browseterm -a test123
```

> Note: The setup disables the built-in `default` user and creates the ACL user `browseterm`, so connect with `--user browseterm`. It exposes the instance as the K8s service `browseterm-redis-service:6379` (use this as `REDIS_HOST` for other services).

### 2. Redis Sentinel HA Cluster

> ⚠️ PLANNED / NOT YET IMPLEMENTED — only the single-instance setup below is wired up today (`make dev_redis_single_setup`).

For high availability with automatic failover:

```bash
# Setup Redis Sentinel HA cluster
make dev_redis_sentinel_setup

# Teardown
make dev_redis_sentinel_teardown
```

**Features:**
- 1 Redis master + 2 Redis replicas
- 3 Redis Sentinel instances for monitoring
- Automatic failover detection and promotion
- Master password: `master123`
- Sentinel password: `sentinel123`

**Connection:**
```bash
# Connect via Sentinel (recommended)
redis-cli -h redis-sentinel-service -p 26379 -a sentinel123

# Connect directly to master
kubectl port-forward service/redis-master-clusterip -n browseterm 6379:6379
redis-cli -h localhost -p 6379 -a master123
```

**Monitoring:**
```bash
# Check Sentinel status
redis-cli -h redis-sentinel-service -p 26379 -a sentinel123 sentinel masters

# Check master information
redis-cli -h redis-sentinel-service -p 26379 -a sentinel123 sentinel master mymaster
```

### 3. Redis Cluster

> ⚠️ PLANNED / NOT YET IMPLEMENTED — only the single-instance setup below is wired up today (`make dev_redis_single_setup`).

For horizontal scaling and high performance:

```bash
# Setup Redis Cluster
make dev_redis_cluster_setup

# Teardown
make dev_redis_cluster_teardown
```

**Features:**
- 6 Redis nodes (3 masters + 3 replicas)
- Automatic sharding across masters
- Cluster-aware clients supported
- Password: `test123`

**Connection:**
```bash
# Connect to cluster
kubectl exec -it redis-cluster-0 -n browseterm -- redis-cli -a test123 -c cluster nodes

# Check cluster status
kubectl exec -it redis-cluster-0 -n browseterm -- redis-cli -a test123 -c cluster info
```

## Available Make Targets

```bash
# Show all available targets
make help

# Redis HA targets:
make dev_redis_single_setup      # Setup Redis single instance
make dev_redis_single_teardown   # Teardown Redis single instance
make dev_redis_sentinel_setup    # Setup Redis Sentinel HA cluster
make dev_redis_sentinel_teardown # Teardown Redis Sentinel HA cluster
make dev_redis_cluster_setup     # Setup Redis Cluster
make dev_redis_cluster_teardown  # Teardown Redis Cluster
```

## File Structure

```
redis_ha/
├── env.mk                                 # Environment configuration
├── Makefile                              # Build targets
├── redis_single/
│   └── redis-single.yaml                # Single Redis instance config
├── redis_sentinel/
│   ├── redis-master-configmap.yaml      # Master Redis config
│   ├── redis-master-statefulset.yaml    # Master + Sentinel StatefulSets
│   ├── redis-replica-statefulset.yaml   # Replica StatefulSet
│   ├── redis-services.yaml              # Service definitions
│   └── sentinel-configmap.yaml          # Sentinel config
├── redis_cluster/
│   └── redis-cluster.yaml               # Cluster configuration
└── scripts/development/
    ├── redis_single/
    │   ├── redis_single.setup.sh        # Single instance setup
    │   └── redis_single.teardown.sh     # Single instance teardown
    ├── redis_sentinel/
    │   ├── redis_sentinel.setup.sh      # Sentinel HA setup
    │   └── redis_sentinel.teardown.sh   # Sentinel HA teardown
    └── redis_cluster/
        ├── redis_cluster.setup.sh       # Cluster setup
        └── redis_cluster.teardown.sh    # Cluster teardown
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n browseterm
```

### View Logs
```bash
# Redis single
kubectl logs browseterm-redis -n browseterm

# Sentinel HA
kubectl logs redis-master-0 -n browseterm
kubectl logs redis-sentinel-0 -n browseterm

# Cluster
kubectl logs redis-cluster-0 -n browseterm
```

### Delete Stuck Resources
If pods get stuck during shutdown:
```bash
kubectl delete pod --force --grace-period=0 <pod-name> -n browseterm
```

## Development Notes

- All Redis instances use `redis:7-alpine` image for consistency
- Persistent volumes are created for data durability
- Services are configured for internal cluster communication
- SSL/TLS is not enabled by default (add for production use)
- Memory limits and resource requests should be configured based on usage

## Security Considerations

For production deployments:
1. Change default passwords
2. Enable TLS encryption
3. Use network policies for restriction
4. Set appropriate resource limits
5. Monitor memory usage and configure eviction policies
