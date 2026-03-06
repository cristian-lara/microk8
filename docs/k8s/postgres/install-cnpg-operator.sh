#!/usr/bin/env bash
# Install CloudNativePG operator via Helm (recommended over MicroK8s addon).
# Run on the VM: chmod +x docs/k8s/postgres/install-cnpg-operator.sh && ./docs/k8s/postgres/install-cnpg-operator.sh
# From repo root: ./docs/k8s/postgres/install-cnpg-operator.sh
# See docs/08-notas-implementacion.md §9 and workflow/services/postgres/steps.md step 2.

set -e
echo "Adding CloudNativePG Helm repo..."
microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts
microk8s helm3 repo update

echo "Installing CloudNativePG operator in cnpg-system..."
microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace

echo ""
echo "Verification: operator pods in cnpg-system (wait until Running):"
microk8s kubectl get pods -n cnpg-system
