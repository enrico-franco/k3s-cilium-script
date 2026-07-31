# k3s + Cilium Installation Guide

This repository installs a single-node Kubernetes cluster on a Debian or Ubuntu host.
The cluster uses these components:

- [K3s](https://k3s.io/) — a lightweight Kubernetes distribution
- [Cilium](https://cilium.io/) — the CNI, with eBPF-based networking
- [Helm](https://helm.sh/) — the package manager for Kubernetes
- [Flux](https://fluxcd.io/) — GitOps continuous delivery, optional

## Files

| File | Role |
| --- | --- |
| `provision-k3s.sh` | The installation script. k3s keeps the default `kube-proxy`. Cilium is the CNI. |
| `kube-proxy-replacement.patch` | An optional patch for the script. Cilium replaces `kube-proxy`. |

There is one script. The patch gives the second variant, and does not replace the
script.

## Installation

> [!WARNING]
> The script changes the host and cannot undo the changes. It disables swap and
> writes to `/etc/fstab`, `/etc/sysctl.d/`, and `/root/.bashrc`. Run it only on 
> a fresh host.

Run the script as root:

```bash
sudo ./provision-k3s.sh
```

When the script is complete, run `source /root/.bashrc` to get the shell completions.

## Versions

The versions are pinned at the top of the script:

```bash
K3S_VERSION="v1.35.5+k3s1"
CILIUM_VERSION="1.19.4"
HELM_VERSION="v3.21.1"
```

To change a version, edit the value in the script.

## Optional: Cilium replaces kube-proxy

In this variant, k3s starts without `kube-proxy`, and Cilium does the service routing.
The variant also turns on L2 announcements.

Apply the patch, then run the script:

```bash
git apply kube-proxy-replacement.patch
sudo ./provision-k3s.sh
```

The patch makes these changes to the script:

- It adds `disable-kube-proxy: true` to the k3s configuration, and deletes the
  `kube-proxy-arg` block. k3s does not start `kube-proxy`, and the metrics argument has
  no more use.
- It finds the node IP and writes it to `k8sServiceHost`. Cilium cannot use a service
  VIP to reach the API server while it replaces `kube-proxy`.
- It adds `kubeProxyReplacement: true`, `bpf.masquerade: true`,
  `l2announcements.enabled: true`, and `image.pullPolicy: IfNotPresent` to the Cilium
  values.

To go back to the default `kube-proxy`, reverse the patch:

```bash
git apply -R kube-proxy-replacement.patch
```

> [!CAUTION]
> The patch holds fixed line numbers and 6 lines of context. If you edit the k3s
> configuration block or the Cilium values block, regenerate the patch.

## Optional: Flux

To install Flux, set this variable at the top of the script:

```bash
FLUX_INSTALL="true"
```

Then run the script.

## Optional: Hubble

Hubble, Hubble Relay, and Hubble UI are off. To turn them on, set the three
`enabled` keys in the Cilium values block of the script to `true`.

If the patch is applied, or if you plan to apply it, set the same keys in
`kube-proxy-replacement.patch` also. The patch holds these lines as context, and
`git apply` writes the values from the patch into the result.

## Notes

The script also writes a `coredns-custom` ConfigMap. This ConfigMap returns `NOERROR`
for `AAAA` queries on `cluster.local` and `in-addr.arpa`. As a result, CoreDNS stops
the unwanted IPv6 lookups.

k3s starts with F lannel, the network policy controller, the cloud controller, Traefik,
ServiceLB, and local-storage all disabled. Cilium gives the network functions in their
place.
