#!/usr/bin/env bash
set -euo pipefail

DEBIAN_FRONTEND=noninteractive

K3S_VERSION="v1.34.4+k3s1"
CILIUM_VERSION="1.19.2"

USE_FLUX=""

log() { echo -e "\n\t--- $* ---\n"; }

echo "###### Installation of k3s with cilium + helm ######"

log "Remove the SWAP"

swapoff -a 2>/dev/null || true
sed -i '/swap/d' /etc/fstab
rm -f /swap.img

log "Install Dependencies"

apt update -qq
apt install -y bash-completion curl

cat << 'EOF' >> /root/.bashrc
# bash completion
. /usr/share/bash-completion/bash_completion
EOF

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

cat << 'EOF' >> /root/.bashrc
# helm completions
. <(helm completion bash)
EOF

log "Add Kernel Parameters"

cat << 'EOF' > /etc/sysctl.d/90_k3s.conf
vm.panic_on_oom=0
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
kernel.keys.root_maxbytes=25000000
fs.inotify.max_user_instances=1024
EOF

cat << 'EOF' > /etc/sysctl.d/91_cilium.conf
net.ipv4.ip_forward=1
EOF

cat << 'EOF' > /etc/sysctl.d/92_flux.conf
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
EOF

sysctl --system

log "Install k3s"

mkdir -p /etc/rancher/k3s

cat << 'EOF' > /etc/rancher/k3s/config.yaml
cluster-init: true
cluster-cidr: "10.42.0.0/16"
service-cidr: "10.43.0.0/16"
cluster-dns: "10.43.0.10"
flannel-backend:
- none
disable-network-policy: true
disable-cloud-controller: true
disable-kube-proxy: true
disable:
- traefik
- servicelb
- local-storage
kube-controller-manager-arg:
- allocate-node-cidrs
EOF

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server

cat << 'EOF' >> /root/.bashrc
# kube aliases and completion
. <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF

log "Install cilium"


mkdir -p /usr/local/etc/cilium/

cat << 'EOF' > /usr/local/etc/cilium/values.yaml
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
operator:
  replicas: 1
k8sServiceHost: "auto"
k8sServicePort: 6443
kubeProxyReplacement: true
bpf:
  masquerade: true
l2announcements:
  enabled: true
EOF

helm repo add cilium https://helm.cilium.io/
helm repo update

# wait until the cluster is ready
log "Waiting for k3s API to turn active..."
until kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes >/dev/null 2>&1; do
  sleep 2
done

log "Cluster Ready, continue with deploying of manifests"

helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --wait \
  -f /usr/local/etc/cilium/values.yaml

if [ "$USE_FLUX" = "true" ]; then

log "Install flux"

curl -sfL https://fluxcd.io/install.sh | sudo bash

cat << 'EOF' >> /root/.bashrc
# flux completion
. <(flux completion bash)
EOF

fi

echo -e "Remember to run `source .bashrc` to enable completions for the new installed applications!"
