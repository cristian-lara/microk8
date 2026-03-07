#!/usr/bin/env bash
# Install/upgrade Keycloak in namespace platform using external PostgreSQL (platform-db).
# Prerequisites:
#   1. Database 'keycloak' and user 'keycloak' created in platform-db
#   2. Secrets created: keycloak-db-secret (password), keycloak-admin-secret (admin-password)
#
# On VM after git pull:
#   chmod +x docs/k8s/keycloak/apply-keycloak-platform.sh && ./docs/k8s/keycloak/apply-keycloak-platform.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Keycloak Deployment ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check if secrets exist
if ! microk8s kubectl get secret keycloak-db-secret -n platform &>/dev/null; then
  echo "ERROR: Secret 'keycloak-db-secret' not found in namespace platform."
  echo "Create it with: microk8s kubectl create secret generic keycloak-db-secret --namespace platform --from-literal=password='<db-password>'"
  exit 1
fi

if ! microk8s kubectl get secret keycloak-admin-secret -n platform &>/dev/null; then
  echo "ERROR: Secret 'keycloak-admin-secret' not found in namespace platform."
  echo "Create it with: microk8s kubectl create secret generic keycloak-admin-secret --namespace platform --from-literal=admin-password='<admin-password>'"
  exit 1
fi

echo "Prerequisites OK."
echo ""

echo "Adding Bitnami Helm repo..."
microk8s helm3 repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
microk8s helm3 repo update

echo ""
echo "Installing/upgrading Keycloak in namespace platform..."
microk8s helm3 upgrade --install keycloak bitnami/keycloak \
  --namespace platform \
  --create-namespace \
  -f values-keycloak-prod.yaml \
  --timeout 10m

echo ""
echo "=== Deployment initiated ==="
echo ""
echo "Keycloak pods (wait for Running):"
microk8s kubectl get pods -n platform -l app.kubernetes.io/name=keycloak

echo ""
echo "Note: Keycloak may take 2-5 minutes to start on first run (DB schema creation)."
echo "Monitor with: microk8s kubectl logs -n platform -l app.kubernetes.io/name=keycloak -f"
echo ""
echo "Once running, access at: https://keycloak.cld-lf.com"
echo "Admin user: admin"
echo "Admin password: (from keycloak-admin-secret)"
