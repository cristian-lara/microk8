# 02 - MicroK8s bootstrap en Ubuntu 24.04 (paso a paso)

## Instalación
1. `sudo snap install microk8s --classic`
2. `sudo usermod -a -G microk8s $USER`
3. `newgrp microk8s`
4. `microk8s status --wait-ready`

## Add-ons base
- `microk8s enable dns`
- `microk8s enable helm3`

**Ingress:** no usar el addon `microk8s enable ingress`. Instalar el controlador Ingress vía **Helm** (ingress-nginx) para tener control, versionado y mejores prácticas. Ver sección "Ingress vía Helm" más abajo.

Para **storage**:
- Entorno dev/lab sencillo: se puede usar `microk8s enable hostpath-storage`.
- Entorno \"productivo\" en VM + NAS: ver `02b-storage-nfs-synology.md` para configurar `nfs-storage` (NFS en Synology) como StorageClass por defecto.

## Ingress vía Helm (mejores prácticas)

Instalar el controlador Ingress con Helm en lugar del addon de MicroK8s:

```bash
microk8s helm3 repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
microk8s helm3 repo update
microk8s helm3 install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=80
```

Ajustes recomendados (values o `--set`): imagen versionada (no `:latest`), recursos (requests/limits), y según necesidad `controller.metrics.enabled`, `controller.podAnnotations`. Para producción con Cloudflare Tunnel, el túnel suele apuntar a `http://127.0.0.1:80` o al NodePort del controller; si se prefiere evitar NodePort, se puede exponer el Service del controller por un puerto fijo y documentarlo en `docs/08-notas-implementacion.md`.

Validar: `microk8s kubectl get pods -n ingress-nginx` (controller Running).

## Validación
- `microk8s kubectl get nodes`
- `microk8s kubectl get pods -A`
- `microk8s kubectl get pods -n ingress-nginx` (Ingress controller)
