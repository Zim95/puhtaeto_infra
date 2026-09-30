# k3s (single-node, Multipass or a self-owned VM)

A single-node k3s cluster you can run identically on a local Multipass VM (macOS) and on a
self-owned cloud VM or Raspberry Pi in production. See **`k3s_single_node.md`** for the full
rationale (why k3s over docker-desktop/EKS, why single-node, why Traefik/servicelb are disabled in
favor of ingress-nginx/MetalLB) - this README only covers running the scripts and what's in this
directory.

## Setup

```bash
./setup.sh
```

Idempotent - safe to re-run. Provisions (or reuses) a Multipass VM, verifies internet access,
installs k3s with its bundled Traefik/servicelb disabled (kube-router's NetworkPolicy enforcement -
the main reason to use k3s at all - stays on; `local-path`, the default StorageClass, is kept so
PVCs bind), installs gVisor (`runsc`) and registers it with k3s's containerd for sandboxed
workloads, wires up a `kubectl` context pointed at the VM, then installs ingress-nginx and MetalLB
(applying `metallb-config.yaml`'s IP pool - edit that file first if your VM's subnet isn't the
default Multipass `192.168.64.x`).

Override any of `VM`, `CPUS`, `MEM`, `DISK`, `UBUNTU`, `K3S_VERSION`, `CONTEXT`, `KUBECONFIG_PATH`
via environment variables - e.g. `VM=my-cluster CONTEXT=my-cluster ./setup.sh`.

Handy commands afterward: `multipass shell <VM>` · `multipass stop <VM>` ·
`multipass delete --purge <VM>`.

## What's in this directory

- **`setup.sh`** - the cluster bootstrap above.
- **`k3s_single_node.md`** - why single-node k3s, the Traefik/servicelb/MetalLB tradeoffs, the
  local-vs-prod CIDR gotcha, and a real table of migration issues already hit and fixed.
- **`multipass_cluster.md`** - an earlier, multi-node (1 master + 3 workers) exploration with NFS
  for shared storage. Superseded by the simpler single-node approach above (this doc's own final
  section notes the multi-node/NFS path was abandoned - no internet access on that cluster was
  never resolved) - kept for historical reference only, not part of the current setup.
- **`ingress_metallb_setup.md`** + **`metallb-config.yaml`** - the ingress-nginx + MetalLB
  installation `setup.sh` already automates (kept for reference/manual re-runs).
- **`setup_official_cert_manager.md`** + **`letsencrypt-issuer.yaml`** - the official (jetstack)
  cert-manager, for real browser-facing TLS in production (separate from any per-service internal
  mTLS a project might run its own cert-manager for).
- **`minio_setup.md`** + **`minio.yaml`** - MinIO (S3-compatible object storage) via helm.
- **`gvisor-runtimeclass.yaml`** - the `RuntimeClass` object exposing the `gvisor` sandboxed
  runtime `setup.sh` installs at the node level - apply this once the cluster is up so workloads can
  actually request `runtimeClassName: gvisor`.
- **`snapshot-pvc.yaml`** - a shared local-storage PVC for snapshot/scratch use.
- **`device_cloud_grpc_connectivity.md`** - how a remote Cloud cluster and many independent local
  Device clusters reach each other over a persistent streaming gRPC connection (one outbound
  stream per device, Traefik `IngressRoute` + custom `ServersTransport` gotchas and all) - read
  this before wiring up any project's own cloud-to-remote-cluster control channel.
- **`remote_kubectl_via_tailscale.md`** - how to reach this (or any) remote single-node k3s
  cluster's API server directly with `kubectl` from your own Mac, over Tailscale instead of a
  public port or an SSH tunnel - join the same tailnet, add the Tailscale IP to k3s's own
  `tls-san`, then copy/merge the admin kubeconfig. This is how `puhtaeto-prod-o1` is actually
  reached today.

Apply the manifests once the cluster is up, e.g.:

```bash
kubectl apply -f gvisor-runtimeclass.yaml
kubectl apply -f snapshot-pvc.yaml
# minio.yaml and letsencrypt-issuer.yaml: see their own docs above for helm/cert-manager prerequisites first.
```

See `../../observability/` for the shared logs/metrics/dashboards stack (moved out of here - it's
cluster-wide infra, not part of the cluster bootstrap itself).
