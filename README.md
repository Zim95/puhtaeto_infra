# puhtaeto_infra

Shared infrastructure for all Puhtaeto projects (BrowseTerm and whatever comes after it) - cluster
setup, databases, and any other infra tooling that isn't specific to one project's own application
code. Each project repo keeps its own `infra/` directory for its *own* deployment manifests
(Deployments, Services, project-specific Secrets); only infra that's reusable across projects lives
here.

This repo was assembled from content that used to live scattered inside `browseterm-monorepo`
(`00_docs/`, `02_cluster_infra/`) and two standalone repos (`postgres_ha`, `redis_ha`) - see each
subdirectory's own README/docs for the original, unedited setup instructions. Git history for that
content remains in those original repos/locations; this repo starts fresh.

## Layout

- **`cluster/`** - stand up a Kubernetes cluster (Multipass+k3s locally or on a cloud VM, or
  Docker Desktop's own cluster) and the shared infra every cluster needs on top: ingress, MetalLB,
  cert-manager, MinIO, observability (Loki/Grafana/Alloy), gVisor sandboxing.
  - `cluster/docs/` - setup guides, one per tool:
    - `multipass_cluster.md` - the full Multipass + k3s cluster build (why Multipass over
      minikube/kind - DNS/NFS/HA - and how to create the VMs and join them).
    - `k3s_single_node.md` - the single-node k3s variant BrowseTerm actually runs, both locally
      (Multipass VM) and in production (a cloud VM or Raspberry Pi), plus how egress/internet works
      on it.
    - `local_ip_setup.md` - local IP aliasing for port-forwarding into the cluster from your Mac.
    - `metallb_setup.md` - the Nginx Ingress Controller setup (helm-based).
    - `minio_setup.md` - MinIO (S3-compatible object storage) via helm.
    - `setup_official_cert_manager.md` - the official cert-manager install for browser-facing TLS.
  - `cluster/manifests/` - the actual Kubernetes manifests for shared cluster infra:
    `metallb-config.yaml` (the MetalLB IP address pool - Docker Desktop's own cluster uses
    `192.168.65.x`), `minio.yaml`, `letsencrypt-issuer.yaml` (cert-manager `ClusterIssuer`),
    `gvisor-runtimeclass.yaml` (the sandboxed `RuntimeClass` user workloads request),
    `snapshot-pvc.yaml`, and the observability stack (`loki.yaml`, `grafana.yaml`, `alloy.yaml`).
- **`databases/`** - shared database setups:
  - `databases/postgres/` - Postgres HA setup (etcd-backed), moved in from the standalone
    `postgres_ha` repo - see its own `README.md` for setup instructions.
  - `databases/redis/` - Redis HA setup, moved in from the standalone `redis_ha` repo - see its own
    `README.md` for setup instructions.

## Adding new infra

New shared infra (a vector DB, a file server, a new cluster tool) gets its own subdirectory here
with its own README, following the same pattern as `databases/postgres`/`databases/redis` above -
not a new top-level project repo, and not folded into any one project's own `infra/` directory.
