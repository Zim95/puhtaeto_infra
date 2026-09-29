# Databases (shared Postgres + Redis)

A single shared PostgreSQL instance and a single shared Redis instance, meant to back **every**
project (ikompare today, Browseterm and whatever comes later too) rather than each project running
its own. Adapted from ikompare's own real, production-verified setup.

- **`namespace.yaml`** - the `data` namespace both databases live in. Carries its own
  `data-access: "true"` label (not just used to gate other namespaces): a `NetworkPolicy`
  `namespaceSelector` evaluates the *connecting* pod's namespace, and a same-namespace client (a
  migration Job living here to share Postgres's own Secret, say) would never match its own policy
  without this label on its own namespace too.
- **`networkpolicy.yaml`** - grants ingress to Postgres (`5432`) and Redis (`6379`) from *any*
  namespace labeled `data-access: "true"`, rather than listing every individual client pod. A new
  project only needs to label its own namespace - this file never needs to change for it.

See `postgres/` and `redis/` for each database's own setup script and README. Both `setup.sh`
scripts apply `namespace.yaml`/`networkpolicy.yaml` themselves (idempotent), so either one works
standalone regardless of which you run first.

**Caveat (kube-router, k3s's default CNI):** NetworkPolicy enforcement has a real timing gap for
freshly-created pods - a client pod that starts and immediately tries to connect can get a real
`connection refused` before its own namespace's policy membership has propagated. A retry/backoff
on first connection (most DB clients and migration tools already do this) is the fix, not a bigger
timeout on the database side.
