#!/usr/bin/env bash
# Install CloudNativePG operator via Helm (recommended over MicroK8s addon).
# Run on the VM: chmod +x docs/k8s/postgres/install-cnpg-operator.sh && ./docs/k8s/postgres/install-cnpg-operator.sh
# From repo root: ./docs/k8s/postgres/install-cnpg-operator.sh
# See docs/08-notas-implementacion.md §9 and workflow/services/postgres/steps.md step 2.
# If Helm fails with "ConfigMap cnpg-default-monitoring exists... invalid ownership metadata",
#   do a clean install: microk8s kubectl delete namespace cnpg-system ; then re-run this script.
# If Helm fails with "CRD ... exists ... release-namespace must equal cnpg-system: current value is platform",
#   either: (A) uninstall from platform, delete CRDs (grep postgresql.cnpg.io | xargs delete), re-run; or
#   (B) install without creating CRDs: add --set crds.create=false to the helm install line below (or run the one-liner from docs/08-notas-implementacion.md §9).

set -e
echo "Adding CloudNativePG Helm repo..."
microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts
microk8s helm3 repo update

echo "Installing CloudNativePG operator in cnpg-system..."
microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace

echo ""
echo "Verification: operator pods in cnpg-system (wait until Running):"
microk8s kubectl get pods -n cnpg-system
