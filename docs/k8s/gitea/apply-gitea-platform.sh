#!/usr/bin/env bash
# Install/upgrade Gitea in namespace platform using nfs-storage.
# On VM after git pull: chmod +x docs/k8s/gitea/apply-gitea-platform.sh && ./docs/k8s/gitea/apply-gitea-platform.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Adding Gitea Helm repo..."
microk8s helm3 repo add gitea-charts https://dl.gitea.io/charts/ 2>/dev/null || true
microk8s helm3 repo update

echo "Installing/upgrading Gitea in namespace platform..."
microk8s helm3 upgrade --install gitea gitea-charts/gitea \
  --namespace platform \
  --create-namespace \
  -f values-gitea-prod.yaml

echo ""
echo "Pods (Gitea should reach Running):"
microk8s kubectl get pods -n platform -l app.kubernetes.io/name=gitea

