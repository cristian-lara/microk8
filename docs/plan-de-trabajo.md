# Plan de trabajo – MicroK8s + Cloudflare Tunnel (cld-lf.com)

Objetivo: levantar la plataforma **sin port forwarding**; cada app con su **subdominio** saliendo por **443**.

**Convención:** Para cada actividad que implique despliegue o configuración se indican los **archivos a crear** (manifests, values, scripts) y el **script o comando a ejecutar**. Los scripts de apply suelen vivir en `docs/k8s/<componente>/` y se ejecutan desde la raíz del repo o desde la VM tras `git pull`.

---

## 1. VM y red

- [x] VM Ubuntu 24.04 creada en Synology VMM
  - Archivos: (config en Synology VMM)
  - Ejecutar: (manual en Dashboard; verificación: `ssh usuario@<IP>`)
- [x] Red bridge configurada (LAN `192.168.50.0/24`)
  - Archivos: (config en Synology VMM)
  - Ejecutar: (manual)
- [x] Reserva DHCP para la VM (ej. `192.168.50.237`)
  - Archivos: (config en router/DHCP)
  - Ejecutar: (manual)
- [x] SSH local funcionando: `ssh usuario@192.168.50.237`
  - Ejecutar: `ssh usuario@192.168.50.237`

---

## 2. MicroK8s en la VM

- [x] MicroK8s instalado (`snap install microk8s --classic` o ya por defecto)
  - Archivos: `docs/k8s/scripts/bootstrap-microk8s.sh` (opcional, para replicar)
  - Ejecutar: `snap install microk8s --classic`; luego `sudo usermod -a -G microk8s $USER` y `newgrp microk8s`
- [x] Cluster listo: `microk8s status --wait-ready`
  - Ejecutar: `microk8s status --wait-ready`
- [x] Addon DNS: `microk8s enable dns`
  - Ejecutar: `microk8s enable dns`
- [x] Addon Helm: `microk8s enable helm3`
  - Ejecutar: `microk8s enable helm3` (requerido antes de instalar Ingress u otros charts).
- [x] Ingress instalado vía Helm (ingress-nginx), no addon
  - Archivos: ver `docs/02-microk8s-bootstrap.md` (sección Ingress vía Helm) y `docs/08-notas-implementacion.md` §3b.
  - Ejecutar: añadir repo Helm `ingress-nginx`, instalar chart en namespace `ingress-nginx` con valores según mejores prácticas (imagen versionada, resources). No usar `microk8s enable ingress`.
- [x] Storage configurado: `nfs-storage` (NFS Synology) como StorageClass por defecto; `hostpath-storage` deshabilitado
  - Archivos: `docs/k8s/scripts/setup-nfs-storage.sh` (opcional) o ver `08-notas-implementacion.md`
  - Ejecutar: (Helm install nfs-subdir-external-provisioner; ver notas)
- [x] Validación: `microk8s kubectl get nodes` (Ready)
  - Ejecutar: `microk8s kubectl get nodes` y `microk8s kubectl get pods -A`

---

## 3. Cloudflare Tunnel (sin port forwarding)

- [x] Túnel creado en Cloudflare Zero Trust (Dashboard)
  - Archivos: (config en Cloudflare Zero Trust)
  - Ejecutar: (manual en Dashboard)
- [x] `cloudflared` instalado (en la VM o en el NAS)
  - Ejecutar: `sudo cloudflared service install <TOKEN>` (ver `08-notas-implementacion.md`)
- [x] Túnel configurado y conectado (token o config)
  - Ejecutar: `sudo systemctl status cloudflared`
- [x] Verificar que el tráfico sale por 443 hacia Cloudflare (no hay port forwarding en el NAS)
  - Ejecutar: (comprobar en router/NAS que no hay port forwarding)

---

## 4. Cloudflare Access

- [x] Access configurado con IdP (Google)
  - Archivos: (config en Cloudflare Zero Trust → Access → Authentication)
  - Ejecutar: (manual en Dashboard)
- [x] MFA habilitado para servicios sensibles
  - Ejecutar: (manual en Dashboard por aplicación)
- [x] Allowlist inicial definida (emails permitidos)
  - Archivos: (documentar en `docs/` o en Dashboard)
  - Ejecutar: (manual en Dashboard)
- [x] Piloto: `test.cld-lf.com` creado y protegido con Access
  - Archivos: (registro DNS Tunnel/CNAME + Access App en Dashboard)
  - Ejecutar: (manual); verificación: abrir `https://test.cld-lf.com`

---

## 5. Plataforma en MicroK8s (apps internas)

- [x] Namespace de plataforma creado (ej. `platform` o similar) para aislar los componentes de plataforma (Vault, PostgreSQL, Gitea, ArgoCD, etc.) del resto de namespaces
  - Archivos: `docs/k8s/scripts/create-namespace-platform.sh` (opcional)
  - Ejecutar: `microk8s kubectl create namespace platform`
- [ ] **Operador CloudNativePG** instalado (requerido antes de desplegar PostgreSQL)
  - Archivos: (documentado en `docs/08-notas-implementacion.md` §9)
  - Ejecutar (en la VM, **recomendado Helm**): `microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts && microk8s helm3 repo update && microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace`. Verificación: `microk8s kubectl get pods -n cnpg-system`
- [ ] **PostgreSQL** (CloudNativePG) usando `nfs-storage`
  - Archivos: `docs/k8s/postgres/postgres-platform.yaml`, `docs/k8s/postgres/apply-postgres-platform.sh`, `docs/k8s/postgres/create-gitea-db.sh` (opcional, para crear DB Gitea)
  - Ejecutar: `chmod +x docs/k8s/postgres/apply-postgres-platform.sh && ./docs/k8s/postgres/apply-postgres-platform.sh` (desde la raíz del repo). Luego, si vas a desplegar Gitea: `GITEA_DB_PASSWORD='...' chmod +x docs/k8s/postgres/create-gitea-db.sh && ./docs/k8s/postgres/create-gitea-db.sh`
- [ ] **Vault** desplegado y apuntando a storage NFS
  - Archivos: `docs/k8s/vault/values-vault-prod.yaml`, `docs/k8s/vault/apply-vault-platform.sh`
  - Ejecutar: `chmod +x docs/k8s/vault/apply-vault-platform.sh && ./docs/k8s/vault/apply-vault-platform.sh` (desde la raíz del repo)
- [ ] **Vault vinculado a PostgreSQL** (motor database, credenciales dinámicas, rotación para Gitea/ArgoCD)
  - Archivos: `docs/k8s/vault/vault-postgres-integration.md`, `docs/k8s/postgres/create-vault-db-user.sh`, `docs/k8s/postgres/grant-vault-to-gitea.sh`, `docs/k8s/vault/setup-database-engine.sh`
  - Ejecutar: (1) `VAULT_DB_ADMIN_PASSWORD='...' ./docs/k8s/postgres/create-vault-db-user.sh` (2) Crear DB gitea si aplica y `./docs/k8s/postgres/grant-vault-to-gitea.sh` (3) Tras unseal Vault: `VAULT_ADDR=... VAULT_TOKEN=... VAULT_DB_ADMIN_PASSWORD=... ./docs/k8s/vault/setup-database-engine.sh`. Ver orden completo en `docs/k8s/vault/vault-postgres-integration.md`
- [ ] **Gitea** desplegado
  - Archivos: `docs/k8s/gitea/values-gitea-prod.yaml`, `docs/k8s/gitea/apply-gitea-platform.sh`
  - Ejecutar: `chmod +x docs/k8s/gitea/apply-gitea-platform.sh && ./docs/k8s/gitea/apply-gitea-platform.sh` (desde la raíz del repo)
- [ ] **ArgoCD** desplegado (para GitOps)
  - Archivos: `docs/k8s/argocd/values-argocd-prod.yaml`, `docs/k8s/argocd/apply-argocd-platform.sh`
  - Ejecutar: `chmod +x docs/k8s/argocd/apply-argocd-platform.sh && ./docs/k8s/argocd/apply-argocd-platform.sh` (desde la raíz del repo)
- [ ] (Opcional) **Woodpecker CI / Registry (Harbor)** desplegados
  - Archivos: `docs/k8s/woodpecker/` y/o `docs/k8s/harbor/` (values + `apply-*.sh` por componente)
  - Ejecutar: `chmod +x docs/k8s/<componente>/apply-*.sh && ./docs/k8s/<componente>/apply-*.sh`
- [ ] Validación: pods de la plataforma `Running` y PVCs creados con `nfs-storage`
  - Archivos: `docs/k8s/scripts/validate-platform.sh`
  - Ejecutar: `chmod +x docs/k8s/scripts/validate-platform.sh && ./docs/k8s/scripts/validate-platform.sh`

---

## 6. Subdominios y apps (todo por 443)

- [ ] **Public Hostnames** en el túnel (un subdominio por app)
  - Archivos: documentar en `docs/06-subdominios-hostnames.md` la lista hostname → servicio:puerto
  - Ejecutar: (manual en Cloudflare Zero Trust: Tunnel → Public Hostname por cada app)
- [ ] (Opcional) **SSH por túnel**: `ssh.cld-lf.com` → VM:22, con Access
  - Archivos: `docs/08-notas-implementacion.md` (sección uso cliente SSH)
  - Ejecutar: (manual: Public Hostname + Access app; luego documentar comando cliente)
- [ ] Migrar **vault.cld-lf.com** (MFA + allowlist estricta)
  - Archivos: `docs/k8s/vault/ingress-vault.yaml`, `docs/k8s/vault/apply-ingress-vault.sh`
  - Ejecutar: `chmod +x docs/k8s/vault/apply-ingress-vault.sh && ./docs/k8s/vault/apply-ingress-vault.sh`; luego configurar Public Hostname en Cloudflare
- [ ] Migrar **argo.cld-lf.com**
  - Archivos: `docs/k8s/argocd/ingress-argocd.yaml`, `docs/k8s/argocd/apply-ingress-argocd.sh`
  - Ejecutar: `chmod +x docs/k8s/argocd/apply-ingress-argocd.sh && ./docs/k8s/argocd/apply-ingress-argocd.sh`; luego Public Hostname en Cloudflare
- [ ] Migrar **resto de apps** (Gitea, etc.) según necesidad
  - Archivos: `docs/k8s/<app>/ingress-*.yaml`, `docs/k8s/<app>/apply-ingress-*.sh`
  - Ejecutar: `chmod +x docs/k8s/<app>/apply-ingress-*.sh && ./docs/k8s/<app>/apply-ingress-*.sh`; Public Hostname en Cloudflare

---

## 7. Cierre

- [ ] Port forwarding del NAS retirado (ya no se usa)
  - Archivos: (ninguno)
  - Ejecutar: (manual en router/NAS: eliminar reglas de port forwarding)
- [ ] Comprobar que todo el acceso externo es vía Tunnel + subdominios + 443
  - Archivos: `docs/k8s/scripts/validate-access-tunnel.sh` (opcional: curl cada subdominio)
  - Ejecutar: (manual) verificar en router/NAS que no queden port forwarding; probar `https://<subdominio>.cld-lf.com` por cada app

---

## 8. Tareas de prioridad baja / nice-to-have

- [ ] Configurar acceso SSH a la VM por internet usando **Cloudflare Tunnel + Access** (sin port forwarding), con:
  - Archivos: `docs/08-notas-implementacion.md` (sección SSH por Tunnel) y/o `docs/ssh-tunnel-access.md`
  - Ejecutar: (manual) Public Hostname `ssh.cld-lf.com` → VM:22; Access app con MFA y allowlist; documentar uso del cliente (cloudflared / SSH config).

---

_Referencia: `00-resumen.md`, `02-microk8s-bootstrap.md`, `03-cloudflare-tunnel-access-google-mfa.md`, `04-migrar-vault-subdominio.md`. Para flujos de análisis y ejecución por servicio, ver `workflow/README.md`._
