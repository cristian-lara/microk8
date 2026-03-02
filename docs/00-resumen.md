# Resumen

Este resumen describe la arquitectura y decisiones para exponer apps (ArgoCD/Gitea/Vault) por `*.cld-lf.com` usando Cloudflare Tunnel + Cloudflare Access (Google + MFA), sin VPN y sin abrir puertos.

## Decisiones clave
- Infra:
  - VM Ubuntu 24.04 en Synology VMM.
  - Red LAN: `192.168.50.0/24`.
  - Gateway: `192.168.50.1`.
  - NAS/Host: `192.168.50.254`.
- Dominio/DNS:
  - `cld-lf.com` (root) se queda en el NAS (no se modifica).
  - Las apps se publican por subdominios (`vault.cld-lf.com`, `argo.cld-lf.com`, etc.).
- Publicación externa:
  - Método: **Cloudflare Tunnel** (no port-forwarding; funciona con doble NAT/CGNAT).
  - Control de acceso: **Cloudflare Access**.
  - IdP: **Google**.
  - MFA: **sí** (mínimo para `vault` y `argo`).
  - Allowlist inicial:
    - `cristian89lara@gmail.com`
    - `cristian.lara@manticore-labs.com`
- Nota: IP pública reportada `38.224.80.208` queda sólo como referencia; con Tunnel no se depende de ella.

## Componentes dentro de la VM
- Kubernetes:
  - MicroK8s (single-node).
  - Ingress NGINX (MicroK8s addon).
  - Helm.
- Plataforma (objetivo):
  - PostgreSQL (recomendado: CloudNativePG).
  - Vault (secretos/credenciales; NO es SSO).
  - ArgoCD (GitOps).
  - Gitea (Git).
  - Woodpecker (CI).
  - Registry (Harbor opcional; afecta sizing/almacenamiento).

## Orden recomendado de ejecución
1. Crear VM + Ubuntu + red bridge + reserva DHCP.
2. Instalar MicroK8s + addons base.
3. Crear Cloudflare Tunnel.
4. Crear Cloudflare Access y proteger el piloto `test.cld-lf.com`.
5. Migrar `vault.cld-lf.com` (MFA + allowlist estricta).
6. Migrar `argo.cld-lf.com` y luego el resto.
