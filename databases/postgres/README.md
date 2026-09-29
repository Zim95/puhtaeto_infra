# PostgreSQL (shared, single-instance)

A single PostgreSQL instance (`postgres:17.6`, one `StatefulSet` replica with a `PersistentVolumeClaim`)
in the shared `data` namespace (see `../namespace.yaml`) - meant to hold every project's own
database, not one Postgres per project. Adapted from ikompare's own real, production-verified
manifests.

## Setup

```bash
cp postgres.env.example postgres.env   # fill in real values - never commit postgres.env
./setup.sh
```

Idempotent - safe to re-run. Applies the shared `data` namespace + NetworkPolicy, creates/updates
the `postgres-credentials` Secret from `postgres.env`, and deploys the Service + StatefulSet.

## Connecting from your own project's namespace

1. Label your project's namespace `data-access: "true"` - `../networkpolicy.yaml` only allows
   ingress to Postgres/Redis from namespaces carrying that label.
2. Connect at `postgres.data.svc.cluster.local:5432` using your own database's own credentials
   (create a separate database/user inside this same Postgres instance for your project, rather
   than sharing the `postgres-credentials` Secret above across projects).

## Real gotchas already hit and fixed (see the manifest's own comments)

- The official Postgres image's entrypoint needs root + `CAP_CHOWN`/`CAP_FOWNER` for its first-run
  data directory initialization - `runAsNonRoot`/`capabilities.drop: ["ALL"]` would break that;
  only `allowPrivilegeEscalation: false` is set.
- Kubernetes does **not** expand `$(VAR)` inside a probe's `exec.command` array (that substitution
  only applies to a container's own `command`/`args`) - the readiness/liveness probes use a shell
  wrapper (`sh -c 'pg_isready -U "$POSTGRES_USER" ...'`) to read the real environment variable at
  run time instead.
