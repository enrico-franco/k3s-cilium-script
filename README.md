# k3s + Cilium Installation Guide

This repository provides automated scripts to deploy a single-node Kubernetes cluster using:

- [K3s](https://k3s.io/) (lightweight Kubernetes distribution)
- [Cilium](https://cilium.io/) (CNI with eBPF-based networking)
- [Helm](https://helm.sh/) (Kubernetes package manager)
- Optional: [Flux](https://fluxcd.io/) (GitOps continuous delivery)

## Scripts

| Script | Description |
| --- | --- |
| `provision-k3s.sh` | k3s with the default `kube-proxy`, Cilium as CNI. |
| `provision-k3s-kubeproxy.sh` | k3s with `kube-proxy` disabled, Cilium running in kube-proxy replacement mode (`kubeProxyReplacement: true`). The node IP is auto-detected for `k8sServiceHost`. |

Both must be run as **root**.

## Versions

Default versions are defined as variables at the top of each script:

```bash
K3S_VERSION="v1.35.5+k3s1"
CILIUM_VERSION="1.19.4"
HELM_VERSION="v3.21.1"
```

Edit these directly in the script to change them.

The scripts also deploy a CoreDNS override (`coredns-custom` ConfigMap) that returns `NOERROR` for `AAAA` queries on `cluster.local`/`in-addr.arpa`, suppressing unwanted IPv6 lookups.

### Optional: Enabling Flux

To enable Flux installation, set the variable at the top of the script:

```bash
FLUX_INSTALL="true"
```

Then run the script.
