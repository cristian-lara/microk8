# Skill: Exposición HTTPS con Cloudflare (sin port forwarding)

Todos los servicios que deban ser accesibles desde internet en este proyecto se exponen por **HTTPS (443)** usando **Cloudflare Tunnel + (opcional) Cloudflare Access**, **sin port forwarding** en el router/NAS.

## Principios

- **No** se abren puertos (80/443) en el router hacia la VM.
- El tráfico sale desde la VM (o donde corra `cloudflared`) hacia Cloudflare por un túnel outbound.
- Cloudflare termina TLS y entrega las peticiones al Ingress del cluster (o al servicio indicado en el Public Hostname).
- **Cloudflare Access** (opcional pero recomendado): IdP (ej. Google), MFA, allowlist por aplicación.

## Pasos para exponer un servicio (checklist)

### 1. Ingress en el cluster

- Crear recurso **Ingress** en el namespace del servicio.
- Host: subdominio que se usará (ej. `vault.cld-lf.com`, `gitea.cld-lf.com`).
- Backend: `Service` del servicio (ClusterIP) y puerto correcto.
- Anotaciones si el Ingress controller lo requiere (ej. cert-manager, o sin TLS si Cloudflare termina TLS).
- Aplicar: `kubectl apply -f docs/k8s/<servicio>/ingress-*.yaml` o script `apply-ingress-<servicio>.sh`.

**Criterio:** Ingress creado; `kubectl get ingress -n <namespace>` muestra el host correcto.

### 2. Public Hostname en el túnel (Cloudflare Zero Trust)

- En **Zero Trust** → **Networks** → **Tunnels** → túnel (ej. `home-microk8s`).
- **Public Hostname**: añadir (o editar) una ruta:
  - **Subdomain** (o custom hostname): ej. `vault` → `vault.cld-lf.com`.
  - **Service type**: HTTP (o HTTPS si el backend es HTTPS).
  - **URL**: apuntar al **Ingress** o al nodo donde el Ingress escucha. Típicamente: `http://<ingress-controller-service>.<namespace>.svc.cluster.local` o la IP:puerto del Ingress (ej. `http://10.152.183.x:80` si el Ingress está en el cluster). En MicroK8s con addon Ingress suele ser `http://localhost:80` desde el host del túnel, o la IP del nodo y puerto 80.
- Guardar.

**Nota:** Si `cloudflared` corre en la VM y el Ingress está en la misma VM, la URL suele ser `http://127.0.0.1:80` o `http://<node-ip>:80` (puerto del Ingress).

**Criterio:** En la configuración del túnel aparece el Public Hostname para ese subdominio.

### 3. DNS (registro CNAME o Tunnel)

- En **Cloudflare DNS** (o donde esté el dominio): crear registro para el subdominio.
  - Tipo: **CNAME** con target el túnel (ej. `<tunnel-uuid>.cfargotunnel.com`) o tipo **Tunnel** si el dashboard lo ofrece.
  - Nombre: ej. `vault` para `vault.cld-lf.com`.
- Sin este paso, el navegador no resuelve el hostname (NXDOMAIN).

**Criterio:** `dig vault.cld-lf.com` (o equivalente) resuelve al túnel/Cloudflare.

### 4. Cloudflare Access (recomendado para apps sensibles)

- En **Zero Trust** → **Access** → **Applications**: crear (o editar) aplicación.
  - **Application domain**: ej. `vault.cld-lf.com` (debe coincidir con el Public Hostname y el DNS).
  - **Policy**: allowlist (emails, grupos) y/o MFA.
- Para servicios muy sensibles (Vault, ArgoCD): MFA + allowlist estricta.

**Criterio:** Al abrir `https://vault.cld-lf.com` se muestra la pantalla de Access (login) y, tras autenticar, la app.

### 5. Validación

- Navegar a `https://<subdominio>.cld-lf.com`: debe cargar la app (o la pantalla de Access) por **HTTPS**, sin errores de certificado (Cloudflare presenta certificado válido).
- Confirmar que **no** hay port forwarding en el router para 80/443 hacia la VM.

## Resumen para el workflow

- Cualquier servicio **expuesto externamente** debe tener: **Ingress** + **Public Hostname en el túnel** + **registro DNS** + (recomendado) **Access**.
- Documentar en `docs/06-subdominios-hostnames.md` (o equivalente) la lista: hostname → servicio:puerto/backend.
- Los **callbacks y webhooks** de la app deben usar el **dominio público** (`https://<subdominio>.cld-lf.com`), no `localhost` ni IP privada (regla en k8s-yaml-prod).

## Referencias

- `docs/03-cloudflare-tunnel-access-google-mfa.md`
- `docs/08-notas-implementacion.md` §4 (gotchas DNS, NXDOMAIN, rutas privadas)
- `docs/plan-de-trabajo.md` §4 (Access), §6 (subdominios)
