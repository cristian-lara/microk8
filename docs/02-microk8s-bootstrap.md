# 02 - MicroK8s bootstrap en Ubuntu 24.04 (paso a paso)

## Instalación
1. `sudo snap install microk8s --classic`
2. `sudo usermod -a -G microk8s $USER`
3. `newgrp microk8s`
4. `microk8s status --wait-ready`

## Add-ons base
- `microk8s enable dns`
- `microk8s enable ingress`
- `microk8s enable helm3`

Para **storage**:
- Entorno dev/lab sencillo: se puede usar `microk8s enable hostpath-storage`.
- Entorno \"productivo\" en VM + NAS: ver `02b-storage-nfs-synology.md` para configurar `nfs-storage` (NFS en Synology) como StorageClass por defecto.

## Validación
- `microk8s kubectl get nodes`
- `microk8s kubectl get pods -A`
