#!/usr/bin/env bash
set -euo pipefail

DEBIAN_FRONTEND=noninteractive

K3S_VERSION="v1.35.5+k3s1"
CILIUM_VERSION="1.19.4"
HELM_VERSION="v3.21.1"

FLUX_INSTALL=""

log() { echo -e "\n\t--- $* ---\n"; }

echo "###### Installation of k3s with cilium + helm ######"

[ "$(id -u)" -eq 0 ] || { echo "Run the script as root and try again"; exit 1; }

log "Remove the SWAP"

swapoff -a 2>/dev/null || true
sed -i '/swap/d' /etc/fstab
rm -f /swap.img

log "Install Dependencies"

DEBIAN_FRONTEND=noninteractive apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -y bash-completion curl

grep -q '# bash completion' /root/.bashrc || cat << 'EOF' >> /root/.bashrc
# bash completion
. /usr/share/bash-completion/bash_completion
EOF

curl -fsSL https://raw.githubusercontent.com/helm/helm/refs/heads/main/scripts/get-helm-3 | bash -s -- --version "${HELM_VERSION}"

grep -q '# helm completions' /root/.bashrc || cat << 'EOF' >> /root/.bashrc
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

log "Correct CoreDNS behaviout with IPv6"

mkdir -p /var/lib/rancher/k3s/server/manifests

cat << 'EOF' > /var/lib/rancher/k3s/server/manifests/noaaaa-coredns.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  noaaaa.override: |
    template IN AAAA cluster.local in-addr.arpa {
      rcode NOERROR
    }
EOF

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

grep -q '# kube aliases and completion' /root/.bashrc || cat << 'EOF' >> /root/.bashrc
# kube aliases and completion
. <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
EOF

log "Install cilium"

K8S_SERVICE_HOST="$(ip -o route get 9.9.9.9 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')"

mkdir -p /usr/local/etc/cilium/

cat << EOF > /usr/local/etc/cilium/values.yaml
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
k8sServiceHost: "$K8S_SERVICE_HOST"
k8sServicePort: 6443
kubeProxyReplacement: true
bpf:
  masquerade: true
l2announcements:
  enabled: true
EOF

helm repo add cilium https://helm.cilium.io/ --force-update
helm repo update

# wait until the cluster is ready
log "Waiting for k3s API to turn active..."
for i in $(seq 1 60); do
  kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes >/dev/null 2>&1 && break
  [ "$i" -eq 60 ] && { log "k3s API did not come up in time"; exit 1; }
  sleep 2
done

log "Cluster Ready, continue with deploying of manifests"

helm upgrade --install cilium cilium/cilium \
  --kubeconfig /etc/rancher/k3s/k3s.yaml \
  --namespace kube-system \
  --version "$CILIUM_VERSION" \
  --wait \
  -f /usr/local/etc/cilium/values.yaml

if [ "$FLUX_INSTALL" = "true" ]; then

log "Install flux"

curl -sfL https://fluxcd.io/install.sh | bash

grep -q '# flux completion' /root/.bashrc || cat << 'EOF' >> /root/.bashrc
# flux completion
. <(flux completion bash)
EOF

fi

echo 'Remember to run `source .bashrc` to enable completions for the new installed applications!'
