# Reproduce Secure Remote `kubectl` Access to k3s

This guide connects a Mac to a remote single-node k3s cluster through Tailscale. It uses placeholders so the procedure can be repeated for another server.

## Prerequisites

- k3s is installed and running on the VPS.
- `kubectl` is installed on the Mac.
- You can SSH into the VPS with a sudo-capable user.
- Tailscale is installed on the Mac.
- Optional: a DNS name such as `k8s.example.com`.

Use these placeholders throughout:

```bash
export CLUSTER_NAME="<cluster-name>"
export VPS_SSH="<user>@<vps-address>"
export K3S_TAILSCALE_IP="<vps-tailscale-ip>"
export K3S_API_HOSTNAME="<optional-k8s-dns-name>"
```

## 1. Create the DNS record (optional)

At the domain provider, create an `A` record:

```text
Type:  A
Host:  k8s
Value: <VPS_PUBLIC_IP>
```

Verify it from the Mac:

```bash
dig +short "$K3S_API_HOSTNAME"
```

DNS provides a stable name but does not secure the Kubernetes API. Tailscale provides the private network path.

## 2. Join the VPS and Mac to the same Tailscale network

Run on the VPS:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname="<server-hostname>"
tailscale status
tailscale ip -4
```

On the Mac, open the Tailscale app and sign in to the same account/tailnet. Then verify connectivity:

```bash
tailscale status
tailscale ping "$K3S_TAILSCALE_IP"
```

## 3. Add the remote address to the k3s API certificate

SSH into the VPS:

```bash
ssh "$VPS_SSH"
sudoedit /etc/rancher/k3s/config.yaml
```

Preserve any existing settings and add one `tls-san` section:

```yaml
tls-san:
  - "<vps-tailscale-ip>"
  - "<optional-k8s-dns-name>"
```

If no DNS name is being used, omit that line. Restart and verify k3s:

```bash
sudo systemctl restart k3s
sudo systemctl is-active k3s
sudo k3s kubectl get nodes
exit
```

Confirm from the Mac that the Tailscale IP appears in the certificate SANs:

```bash
echo | openssl s_client \
  -connect "${K3S_TAILSCALE_IP}:6443" 2>/dev/null | \
  openssl x509 -noout -ext subjectAltName
```

## 4. Copy the k3s administrator kubeconfig to the Mac

Run on the Mac:

```bash
mkdir -p ~/.kube
umask 077

ssh "$VPS_SSH" \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  > "$HOME/.kube/${CLUSTER_NAME}.yaml"

chmod 600 "$HOME/.kube/${CLUSTER_NAME}.yaml"
```

Change the API endpoint from localhost to the VPS Tailscale IP. On macOS:

```bash
sed -i '' \
  "s#https://127.0.0.1:6443#https://${K3S_TAILSCALE_IP}:6443#" \
  "$HOME/.kube/${CLUSTER_NAME}.yaml"
```

Test the standalone kubeconfig:

```bash
kubectl --kubeconfig "$HOME/.kube/${CLUSTER_NAME}.yaml" get nodes
kubectl --kubeconfig "$HOME/.kube/${CLUSTER_NAME}.yaml" get pods -A
```

## 5. Merge it into the existing Mac kubeconfig

k3s names its generated cluster, user, and context `default`. Rename them before merging to avoid collisions:

```bash
sed -i '' \
  -e "s/name: default/name: ${CLUSTER_NAME}/g" \
  -e "s/cluster: default/cluster: ${CLUSTER_NAME}/g" \
  -e "s/user: default/user: ${CLUSTER_NAME}/g" \
  -e "s/current-context: default/current-context: ${CLUSTER_NAME}/g" \
  "$HOME/.kube/${CLUSTER_NAME}.yaml"
```

Back up the current configuration and merge the files:

```bash
touch ~/.kube/config
cp ~/.kube/config ~/.kube/config.backup

MERGED_KUBECONFIG="$(mktemp)"
KUBECONFIG="$HOME/.kube/config:$HOME/.kube/${CLUSTER_NAME}.yaml" \
  kubectl config view --flatten > "$MERGED_KUBECONFIG"

kubectl --kubeconfig "$MERGED_KUBECONFIG" config get-contexts
mv "$MERGED_KUBECONFIG" ~/.kube/config
chmod 600 ~/.kube/config
```

## 6. Use and verify the cluster

```bash
kubectl config get-contexts
kubectl config use-context "$CLUSTER_NAME"
kubectl get nodes -o wide
kubectl get pods -A
```

Switch back to another cluster when needed:

```bash
kubectl config use-context <other-context-name>
```

## Security rules

- Keep TCP port `6443` inaccessible from the public internet; access it through Tailscale only.
- Treat the copied kubeconfig as an administrator credential. Never commit or share it.
- Keep the kubeconfig permission set to `600`.
- Restrict SSH and application ports with the VPS provider firewall and/or UFW.
- Create a least-privilege Kubernetes identity for routine automation instead of reusing the administrator kubeconfig.
- Re-copy the kubeconfig if k3s rotates its administrator certificates.
