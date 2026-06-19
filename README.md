# k3s + Cilium Installation Guide

This repository provides an automated script (`provision-k3s.sh`) to deploy a single-node Kubernetes cluster using:

- [K3s](https://k3s.io/) (lightweight Kubernetes distribution)
- [Cilium](https://cilium.io/) (CNI with eBPF-based networking)
- [Helm](https://helm.sh/) (Kubernetes package manager)
- Optional: [Flux](https://fluxcd.io/) (GitOps continuous delivery)

## Versions

Default versions defined in the script:

```bash
K3S_VERSION="v1.35.5+k3s1"
CILIUM_VERSION="1.19.4"
```

It will add a fix to the AAAA record for the cluster's API server to ensure proper DNS resolution.

You can modify these at the top of the script or using environment variables if needed.

### Optional Enabling Flux

To enable Flux installation, edit the script or modify the environment variable:

```bash
FLUX_INSTALL="true"
```

Then run the script.
