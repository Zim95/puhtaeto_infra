# Docker Desktop (built-in Kubernetes)

Docker Desktop's own built-in single-node Kubernetes. Simplest option if you already have Docker
Desktop running and don't need real NetworkPolicy enforcement (Docker Desktop's CNI accepts
per-tenant NetworkPolicies but silently ignores them - if your project needs isolation actually
enforced, use `../k3s/` instead, which is the entire reason that setup exists over this one).

## Setup

1. In Docker Desktop's settings, enable Kubernetes and wait for it to report "running".
2. ```bash
   ./setup.sh
   ```

Idempotent - safe to re-run. Installs ingress-nginx and MetalLB (Docker Desktop has no
LoadBalancer provider of its own), applying `metallb-config.yaml`'s IP pool
(`192.168.65.200-192.168.65.250` - Docker Desktop's own VM subnet, different from the Multipass
subnet `../k3s/metallb-config.yaml` uses).

## Reaching a service from your Mac

MetalLB's assigned IPs live inside the Docker Desktop VM's own network and are **not** reachable
directly from macOS (a `curl`/`ping` to `192.168.65.2xx` from your Mac times out, even though the
same address works fine from inside the cluster). See **`local_ip_setup.md`** for the workaround:
loopback IP aliases (`ifconfig lo0 alias ...`) mapped to hostnames in `/etc/hosts`, combined with
`kubectl port-forward --address <alias-ip>` for each service you need to reach by name from your
Mac browser/terminal.

## What's in this directory

- **`setup.sh`** - the ingress-nginx + MetalLB install above.
- **`metallb-config.yaml`** - the MetalLB `IPAddressPool`/`L2Advertisement` for Docker Desktop's
  subnet.
- **`local_ip_setup.md`** - the loopback-alias + port-forward technique for reaching services by
  hostname from your Mac. The example hostnames/services in it are illustrative - substitute your
  own project's services and write your own small port-forward script the same way (one
  `kubectl port-forward -n <namespace> --address <alias-ip> svc/<service> <port>:<port> &` line per
  service you need reachable by name).
