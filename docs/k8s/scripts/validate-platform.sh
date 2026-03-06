#!/usr/bin/env bash
# Validate platform namespace: pods Running and PVCs using nfs-storage.
# Run from repo root: chmod +x docs/k8s/scripts/validate-platform.sh && ./docs/k8s/scripts/validate-platform.sh

set -e
echo "Pods in namespace platform:"
microk8s kubectl get pods -n platform

echo ""
echo "PVCs in namespace platform (expect STORAGECLASS nfs-storage, STATUS Bound):"
microk8s kubectl get pvc -n platform

echo ""
echo "StorageClass default:"
microk8s kubectl get storageclass
