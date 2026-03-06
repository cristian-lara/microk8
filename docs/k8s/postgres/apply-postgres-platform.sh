#!/usr/bin/env bash
# Apply CloudNativePG cluster (platform-db) with nfs-storage.
# On VM after git pull: chmod +x docs/k8s/postgres/apply-postgres-platform.sh && ./docs/k8s/postgres/apply-postgres-platform.sh
# From repo root: ./docs/k8s/postgres/apply-postgres-platform.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Applying postgres-platform.yaml in namespace platform..."
microk8s kubectl apply -f postgres-platform.yaml

echo ""
echo "Cluster status:"
microk8s kubectl get clusters.postgresql.cnpg.io -n platform

echo ""
echo "PVCs (expect nfs-storage, Bound):"
microk8s kubectl get pvc -n platform

echo ""
echo "Pods (platform-db-1 should reach Running):"
microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db
