# Plan de trabajo – MicroK8s + Cloudflare Tunnel (cld-lf.com)

Objetivo: levantar la plataforma **sin port forwarding**; cada app con su **subdominio** saliendo por **443**.

---

## 1. VM y red

- [x] VM Ubuntu 24.04 creada en Synology VMM
- [x] Red bridge configurada (LAN `192.168.50.0/24`)
- [x] Reserva DHCP para la VM (ej. `192.168.50.237`)
- [x] SSH local funcionando: `ssh usuario@192.168.50.237`

---

## 2. MicroK8s en la VM

- [x] MicroK8s instalado (`snap install microk8s --classic` o ya por defecto)
- [x] Usuario en grupo: `sudo usermod -a -G microk8s $USER` + `newgrp microk8s`
- [x] Cluster listo: `microk8s status --wait-ready`
- [x] Addon DNS: `microk8s enable dns`
- [x] Addon Ingress: `microk8s enable ingress`
- [x] Addon Helm: `microk8s enable helm3`
- [x] Storage configurado: `nfs-storage` (NFS Synology) como StorageClass por defecto; `hostpath-storage` deshabilitado
- [x] Validación: `microk8s kubectl get nodes` (Ready)
- [x] Validación: `microk8s kubectl get pods -A` (Running donde aplique)

---

## 3. Cloudflare Tunnel (sin port forwarding)

- [x] Túnel creado en Cloudflare Zero Trust (Dashboard)
- [x] `cloudflared` instalado (en la VM o en el NAS)
- [x] Túnel configurado y conectado (token o config)
- [x] Verificar que el tráfico sale por 443 hacia Cloudflare (no hay port forwarding en el NAS)

---

## 4. Cloudflare Access

- [x] Access configurado con IdP (Google)
- [x] MFA habilitado para servicios sensibles
- [x] Allowlist inicial definida (emails permitidos)
- [x] Piloto: `test.cld-lf.com` creado y protegido con Access

---

## 5. Plataforma en MicroK8s (apps internas)

- [x] Namespace de plataforma creado (ej. `platform` o similar) para aislar los componentes de plataforma (Vault, PostgreSQL, Gitea, ArgoCD, etc.) del resto de namespaces
- [ ] PostgreSQL desplegado (ej. CloudNativePG) usando `nfs-storage`
- [ ] Vault desplegado y apuntando a storage NFS
- [ ] Gitea desplegado
- [ ] ArgoCD desplegado (para GitOps)
- [ ] (Opcional) Woodpecker CI / Registry (Harbor) desplegados
- [ ] Validación: pods de la plataforma `Running` y PVCs creados con `nfs-storage`

---

## 6. Subdominios y apps (todo por 443)

- [ ] Un Public Hostname en el túnel por cada app (subdominio propio)
- [ ] (Opcional) SSH por túnel: `ssh.cld-lf.com` → VM:22, con Access si quieres
- [ ] Migrar `vault.cld-lf.com` (MFA + allowlist estricta)
- [ ] Migrar `argo.cld-lf.com`
- [ ] Migrar resto de apps (Gitea, etc.) según necesidad

---

## 7. Cierre

- [ ] Port forwarding del NAS retirado (ya no se usa)
- [ ] Comprobar que todo el acceso externo es vía Tunnel + subdominios + 443

---

_Referencia: `00-resumen.md`, `02-microk8s-bootstrap.md`, `03-cloudflare-tunnel-access-google-mfa.md`, `04-migrar-vault-subdominio.md`._
