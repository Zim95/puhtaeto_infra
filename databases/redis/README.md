# Redis (shared, single-instance)

A single Redis instance (`redis:7.4.1`, AOF-persisted to a `PersistentVolumeClaim` so cache
contents survive a Pod restart) in the shared `data` namespace (see `../namespace.yaml`) - meant to
serve as a shared cache for every project, not one Redis per project (though a project wanting full
isolation can still pick its own key prefix or Redis DB index). Adapted from ikompare's own real,
production-verified manifests. PostgreSQL remains authoritative regardless - a lost or corrupted
AOF file is never anything worse than a cold cache.

## Setup

```bash
./setup.sh
```

Idempotent - safe to re-run. Applies the shared `data` namespace + NetworkPolicy, then the PVC +
Service + Deployment. No credentials file needed - this deployment runs Redis without
`requirepass` (network-isolated via the NetworkPolicy below, not password-protected); add a Secret
+ `--requirepass` yourself first if your setup needs auth in front of it too.

## Connecting from your own project's namespace

Label your project's namespace `data-access: "true"` - `../networkpolicy.yaml` only allows ingress
to Postgres/Redis from namespaces carrying that label - then connect at
`redis.data.svc.cluster.local:6379`.

## Real gotchas already hit and fixed (see the manifest's own comments)

- `runAsNonRoot: true` alone, with no explicit `runAsUser`, makes kubelet refuse to start the
  official Redis image at all ("container has runAsNonRoot and image will run as root") - `runAsUser: 999`
  (the `redis` system user the image itself already creates) is required.
- A plain `Deployment`, not a `StatefulSet`: Redis needs no stable network identity, and the PVC is
  `ReadWriteOnce` anyway (two Pods could never mount it at once) - `strategy.type: Recreate` avoids
  two Redis Pods briefly answering with different cache state during a rollout.
