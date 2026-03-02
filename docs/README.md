# Docs - MicroK8s Platform (cld-lf.com)

Esta carpeta contiene la documentación para levantar la plataforma en una VM Ubuntu 24.04 con MicroK8s y exponer apps por `*.cld-lf.com` usando Cloudflare Tunnel + Cloudflare Access (Google + MFA).

## Plan de trabajo (checks)

**[plan-de-trabajo.md](plan-de-trabajo.md)** – Checklist para ir marcando pasos (VM → MicroK8s → Tunnel → Access → subdominios).

## Orden recomendado
1. `00-resumen.md`
2. `01-vm-ubuntu24-synology-vmm.md`
3. `02-microk8s-bootstrap.md`
4. `02b-storage-nfs-synology.md`
5. `03-cloudflare-tunnel-access-google-mfa.md`
6. `04-migrar-vault-subdominio.md`
