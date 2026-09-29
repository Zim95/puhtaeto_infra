# k3d (k3s-in-Docker, local dev)

A disposable, Docker-based k3s cluster for local development - faster to create/tear down than a
Multipass VM, and doesn't need a whole separate VM per project. Good for quick iteration; see
`../k3s/` instead for a setup that's meant to also run unchanged in production.

## Setup

```bash
./setup.sh
```

Idempotent - safe to re-run. Creates a k3d cluster (Docker Desktop or another Docker engine must
already be running), removes its bundled Traefik, and installs ingress-nginx in its place - k3d's
default Traefik `svclb` DaemonSet squats on host ports 80/443, so anything installed on top of it
without first removing it (including a second ingress controller) ends up permanently `Pending`.

Override `CLUSTER` (cluster name), `LB_PORT` (host port mapped to the cluster's own port 80), and
`INGRESS_NGINX_VERSION` via environment variables.

Teardown: `k3d cluster delete <CLUSTER>` (deletes everything in the cluster - local dev only, no
backups).

## What's in this directory

- **`setup.sh`** - the cluster bootstrap above, extracted and generalized from BrowseTerm's own
  real, verified `SETUP-CLOUD.md`/`SETUP-LOCAL.md` (both used this exact k3d + ingress-nginx-swap
  procedure for two separate local clusters simulating "Cloud" and "Local"). Those docs' remaining
  steps (deploying Postgres/Redis/the app itself) are project-specific, not part of this generic
  bootstrap - see `../../databases/` for the shared Postgres/Redis setup, and deploy your own
  project's workloads on top of this cluster same as any other Kubernetes cluster.
