# Connecting a remote Cloud k3s cluster to many local Device k3s clusters (streaming gRPC)

How BrowseTerm's Cloud cluster (Contabo, prod) and each user's own local Device cluster (a
Multipass VM or a native Linux host, both running k3s per `setup.sh` in this directory) reach each
other, even though they're never on the same network, one is usually behind NAT/no public IP, and
there can be arbitrarily many of them. Generalizes beyond BrowseTerm to any Puhtaeto project that
needs a central cloud cluster to push commands to and stream results from many independent,
customer-controlled clusters.

## Problem

Cloud needs to deliver commands to a specific device (create/resume/hibernate/delete a workspace,
in BrowseTerm's case) and get durable results back, but:

- A device's cluster has no stable public IP and usually can't accept inbound connections at all
  (home NAT/firewalls) - so Cloud can never dial in to a device.
- There can be many devices, so this has to be one connection per device, not a shared tunnel.
- The connection has to survive reconnects (sleep, network changes, pod restarts) without losing
  or duplicating a command.

## Solution: one outbound-only, persistent, bidirectional gRPC stream per device

**The device always dials Cloud; Cloud never dials a device.** Each device runs an agent
(BrowseTerm's `browseterm-device-agent`) that opens one long-lived `DeviceControl.Connect()`
bidirectional gRPC stream outbound to Cloud and keeps it open for as long as the device is up,
reconnecting forever with capped exponential backoff + jitter (`1s, 2s, 4s, 8s, 15s, ~30s`) if it
ever drops. Cloud pushes commands down the stream and the device reports results back up the same
stream - no inbound networking, no VPN, no mesh network, on the device side at all.

**Auth travels inside the stream, not as a channel credential.** The device's own Bearer
device-token goes inside the very first message it sends (a `Hello`), not as a gRPC/HTTP header or
a separate mTLS client cert - a valid TLS connection alone only proves routing/TLS worked, `Hello`
is what actually authenticates and identifies which device this is.

**The client dials the exact same public hostname the REST API uses - not a separate subdomain.**
`CLOUD_CONTROL_HOST`/`CLOUD_CONTROL_PORT` (`app.browseterm.puhtaeto.com:443`) is identical to what
a browser hits for the REST UI+API; the split happens by *path*, not *host* (see below). The
device dials over plain TLS (`grpc.ssl_channel_credentials()`), the same certificate Traefik
already terminates for everything else on that host.

## Implementation (the server side - this is the part that's easy to get wrong)

The gRPC server (`browseterm-control-grpc`, a separate Deployment from the REST API but sharing
its image) is `ClusterIP`-only - Traefik, already fronting the REST Ingress on the same host, is
what actually exposes it to the internet. Getting this right took two real, confirmed-live
failures to nail down:

**1. A plain `networking.k8s.io/v1` Ingress cannot proxy this**, even with the right
`appProtocol`. Traefik 2.x's generic Ingress provider can route to and dial an `h2c` (cleartext
HTTP/2) backend, but its reverse-proxy times out reading a genuinely *streaming* gRPC response
(`ReverseProxy read error during body copy: i/o timeout` in Traefik's own logs) - a real limitation
specific to streaming gRPC, not something a header/annotation fixes. Traefik's own `IngressRoute`
CRD is required instead:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: browseterm-control-grpc-service
spec:
  type: ClusterIP
  selector:
    app: browseterm-control-grpc
  ports:
  - name: grpc
    protocol: TCP
    port: 50060
    targetPort: grpc
    # TLS is already terminated at the edge by the IngressRoute below - this backend speaks
    # cleartext HTTP/2. Traefik's Kubernetes provider reads this standard field itself, no
    # Traefik-specific annotation needed for the common case.
    appProtocol: h2c
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: browseterm-control-grpc-route
spec:
  entryPoints:
    - websecure
  routes:
    - kind: Rule
      # Same host the REST Ingress already owns - routed by PATH (the gRPC service's own fully
      # qualified name), not a second (sub)domain.
      match: Host(`app.browseterm.puhtaeto.com`) && PathPrefix(`/browseterm.device.control.v1.DeviceControl`)
      services:
        - name: browseterm-control-grpc-service
          port: 50060
          scheme: h2c
          serversTransport: control-grpc-transport   # see gotcha 2 below
  tls:
    secretName: browseterm-cloud-tls
```

**2. Even with the `IngressRoute` in place, the stream still dropped every ~60-90s.** Traefik's
*default* `ServersTransport` has `forwardingTimeouts.idleConnTimeout: 90s` - meant for pooled
keep-alive HTTP connections sitting idle *between* separate requests, but it still counts against
one long-lived *streaming* response regardless of activity (confirmed live: the exact same
`i/o timeout` recurred every 60-90s even with the device sending pings every 20s). The fix is a
dedicated `ServersTransport` with that timeout disabled, referenced by the `IngressRoute` above via
`serversTransport:`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: ServersTransport
metadata:
  name: control-grpc-transport
spec:
  forwardingTimeouts:
    dialTimeout: "30s"
    responseHeaderTimeout: "0s"
    idleConnTimeout: "0s"
```

Confirmed live: the control stream held 8+ minutes straight afterward, versus a hard ~60-90s
ceiling before. (An entrypoint-level `respondingTimeouts.readTimeout` override was tried first and
had zero effect - that default was already unlimited; the per-route `ServersTransport` above is
what actually matters.)

**3. Lock down who can reach the internal Service directly**, since Traefik proxying it doesn't by
itself stop other pods in the cluster from dialing it:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: control-grpc-allow-ingress-only
spec:
  podSelector:
    matchLabels:
      app: browseterm-control-grpc
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system   # Traefik itself
      ports:
        - port: grpc
          protocol: TCP
    - from:
        - podSelector:
            matchLabels:
              app: browseterm-server-cloud   # Cloud's own internal calls, e.g. CheckDeviceConnected
      ports:
        - port: grpc
          protocol: TCP
```

## Why this matters for the next project that needs it

Both gotchas above are properties of **Traefik + streaming gRPC**, not anything BrowseTerm-specific
- any Puhtaeto project centralizing control over many remote/customer clusters via a long-lived
streaming RPC (not just request/response REST) will hit the exact same two failure modes. Reuse the
pattern: `appProtocol: h2c` Service + Traefik `IngressRoute` (never a plain `Ingress`) + a
dedicated `ServersTransport` with `idleConnTimeout`/`responseHeaderTimeout` disabled, path-routed
on the same host as everything else rather than a new subdomain per capability.

One historical near-miss worth remembering: this gRPC service ran live on Contabo for 41+ hours
with **zero** external exposure at all before anyone noticed - nothing had ever tried a real
device connection against it yet, so the gap sat invisible. Add and verify the public route
*before* the first real remote client needs it, not after.
