#!/usr/bin/env bash
# Install/upgrade Vault in namespace platform using nfs-storage (values-vault-prod.yaml).
# On VM after git pull: chmod +x docs/k8s/vault/apply-vault-platform.sh && ./docs/k8s/vault/apply-vault-platform.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Adding HashiCorp Helm repo..."
microk8s helm3 repo add hashicorp https://helm.releases.hashicorp.com 2>/dev/null || true
microk8s helm3 repo update

echo "Installing/upgrading Vault in namespace platform..."
microk8s helm3 upgrade --install vault hashicorp/vault \
  --namespace platform \
  --create-namespace \
  -f values-vault-prod.yaml

echo ""
echo "Pods (vault-0 and vault-agent-injector should reach Running):"
microk8s kubectl get pods -n platform -l app.kubernetes.io/name=vault

echo ""
echo "PVCs (expect nfs-storage, Bound):"
microk8s kubectl get pvc -n platform
