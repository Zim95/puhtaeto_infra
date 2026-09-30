# Observability (shared logs, metrics, dashboards)

One shared observability stack meant to watch **every** project on the cluster (BrowseTerm,
ikompare, and whatever comes later), the same shared-infra pattern `../databases/` uses for
Postgres/Redis - not one stack per project.

## What's here today (logs only)

- **`loki.yaml`** - Loki, the log storage/query backend.
- **`alloy.yaml`** - Grafana Alloy, the collection agent. Runs cluster-wide (every namespace, every
  pod), so a new project needs zero extra wiring to get its logs into Loki - just start emitting to
  stdout/stderr like any normal container.
- **`grafana.yaml`** - Grafana itself, the shared dashboard/query UI over Loki.

Deploy into the `observability` namespace:

```bash
kubectl apply -f loki.yaml
kubectl apply -f alloy.yaml
kubectl apply -f grafana.yaml
```

Grafana defaults to `admin`/`admin` on first login - change it. Reach it via
`kubectl port-forward -n observability svc/grafana 3000:3000` (see `../cluster/docker-desktop/local_ip_setup.md` if you need a stable local hostname instead of a raw port-forward).

## What's not here yet (metrics/SLOs)

This stack has no metrics backend (Prometheus/Mimir) or tracing (Tempo) yet - Loki only gives you
log search, not the kind of numeric time series an SLI/SLO/alert needs. Adding metrics collection
is the next real gap to close before any project can define actual SLOs on top of this.

## Convention for project-specific dashboards/alerts

The stack (Loki/Alloy/Grafana, and metrics once added) is shared infra and lives only here. What
each project actually *measures* - its own dashboards, alert rules, SLO/SLI definitions - is
project-specific and should NOT be folded into this directory's manifests. Give each project its
own Grafana folder / alert-rule file/dashboard-as-code checked into that project's own repo (its
`infra/` directory, same as any other project-specific deployment config), querying this shared
Loki (and future Prometheus) instance as the data source - mirroring how each project gets its own
database inside the one shared Postgres instance in `../databases/`, not a separate Postgres per
project.
