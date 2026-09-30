# puhtaeto_infra

Shared infrastructure for all Puhtaeto projects (BrowseTerm, ikompare, and whatever comes after
them) - cluster setup, databases, and any other infra tooling that isn't specific to one project's
own application code. Each project repo keeps its own `infra/` directory for its *own* deployment
manifests (Deployments, Services, project-specific Secrets); only infra that's reusable across
projects lives here.

This repo was assembled from content that used to live scattered across `browseterm-monorepo`
(`00_docs/`, `02_cluster_infra/`, `SETUP-CLOUD.md`, `SETUP-LOCAL.md`), two standalone repos
(`postgres_ha`, `redis_ha`, superseded here by `ikompare`'s own simpler, production-verified
Postgres/Redis setup), and `ikompare`'s own `deploy/data/`. See each subdirectory's own README/docs
for the original, unedited setup instructions. Git history for that content remains in those
original repos/locations; this repo starts fresh.

## Layout

- **`cluster/`** - stand up a Kubernetes cluster, one subdirectory per cluster type, each with its
  own `setup.sh` and README:
  - **`cluster/k3s/`** - single-node k3s (Multipass VM locally, a self-owned cloud VM or Raspberry
    Pi in prod) - the only option here with real NetworkPolicy enforcement (kube-router). Includes
    gVisor sandboxing, ingress-nginx + MetalLB, cert-manager, and MinIO.
  - **`cluster/k3d/`** - k3s-in-Docker, for fast disposable local dev clusters.
  - **`cluster/docker-desktop/`** - Docker Desktop's own built-in Kubernetes - simplest option, but
    no real NetworkPolicy enforcement.
- **`databases/`** - a single shared PostgreSQL instance and a single shared Redis instance meant
  to back every project (not one database pair per project) - see `databases/README.md` for the
  shared-namespace/NetworkPolicy design, and `databases/postgres/`, `databases/redis/` for each
  one's own `setup.sh` and README.
- **`observability/`** - a shared logs/metrics/dashboards stack (Loki/Grafana/Alloy today) meant to
  watch every project on the cluster, same shared-infra pattern as `databases/` - see
  `observability/README.md`.

## Adding new infra

New shared infra (a vector DB, a file server, a new cluster type) gets its own subdirectory here
with its own `setup.sh` and README, following the same pattern as `cluster/k3s/` or
`databases/postgres/` above - not a new top-level project repo, and not folded into any one
project's own `infra/` directory.
