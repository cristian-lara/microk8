# Skill: Catálogo de servicios (market vs custom)

El workflow debe poder desplegar **servicios de mercado** (existentes en el ecosistema) y **servicios custom** (aplicaciones propias). En ambos casos se aplican las mismas mejores prácticas y, si se exponen, salida HTTPS con Cloudflare.

## Clasificación

| Tipo | Descripción | Ejemplos | Origen del manifest |
|------|-------------|----------|----------------------|
| **Market** | Servicios conocidos con Helm charts, operadores o CRDs públicos. | PostgreSQL (CloudNativePG), Vault, Gitea, ArgoCD, Woodpecker, Harbor, n8n, Redis, etc. | Helm values + chart; o YAML oficial/operator. |
| **Custom** | Aplicaciones propias: imagen propia, API, frontend, worker. | App interna, microservicio, job batch. | Deployment/StatefulSet + Service (+ Ingress si se expone) creados desde plantilla. |

Al **analizar** un servicio, clasificarlo como **market** o **custom** y usar el skill correspondiente (checklist por tipo).

---

## Servicios de mercado (referencia en este proyecto)

| Servicio | Namespace típico | BDD | NFS | Vault | Expuesto (HTTPS) | Notas |
|----------|------------------|-----|-----|-------|------------------|--------|
| **PostgreSQL** (CloudNativePG) | platform | — (es la BDD) | Sí (PVC) | No (credenciales por script/env) | No (interno) | Operador CloudNativePG; cluster `platform-db`. |
| **Vault** | platform | No | Sí (storage) | — (es el secret store) | Sí (vault.cld-lf.com, MFA) | Helm; init/unseal; luego motor database para PostgreSQL. |
| **Gitea** | platform | Sí (PostgreSQL) | Sí (repos) | Sí (creds DB dinámicas) | Sí (gitea.cld-lf.com) | Helm; URL raíz y webhooks con dominio público. |
| **ArgoCD** | platform | No (opcional BDD) | No | Sí (creds repo, etc.) | Sí (argo.cld-lf.com, MFA) | Helm; Ingress + Public Hostname. |
| **Woodpecker CI** | platform | Opcional | Opcional | Sí (tokens) | Sí (woodpecker.cld-lf.com) | Helm o manifest; callbacks con dominio público. |
| **Harbor** (registry) | platform | Sí | Sí | Sí (creds) | Sí (harbor.cld-lf.com) | Helm; almacenamiento para imágenes. |
| **n8n** (u otra app) | apps / n8n | Opcional | Opcional | Opcional | Sí (n8n.cld-lf.com) | Helm o Deployment; no en namespace `platform` si es app de negocio. |

- **BDD**: ¿Usa base de datos? (PostgreSQL u otra.)
- **NFS**: ¿Requiere volumen persistente? (StorageClass `nfs-storage`.)
- **Vault**: ¿Requiere secretos/credenciales desde Vault? (ExternalSecret, motor database.)
- **Expuesto**: ¿Se accede desde internet? → Sí: aplicar skill **cloudflare-https-exposure**.

---

## Servicios custom

- **Namespace**: normalmente **no** `platform` (solo componentes de plataforma); usar `apps`, `prod-*`, o nombre de la app.
- **Manifest**: Deployment (o StatefulSet) + Service (ClusterIP) + opcionalmente Ingress.
- **Imagen**: siempre **versionada** (no `:latest`); desde registry propio o público.
- **BDD/NFS/Vault**: según análisis (Fase 1b); si usa BDD, conexión a PostgreSQL u otro; si usa secretos, Vault/ExternalSecret.
- **Exposición**: si la app tiene UI o API pública → Ingress + Cloudflare (Public Hostname + DNS + Access).

Checklist para custom:

- [ ] Namespace correcto (no platform si es app de negocio).
- [ ] Imagen versionada, resources, probes, securityContext (k8s-yaml-prod).
- [ ] Sin credenciales en claro; Vault/ExternalSecret si aplica.
- [ ] Si se expone: Ingress + documentar subdominio y pasos Cloudflare (cloudflare-https-exposure.md).

---

## Uso en el workflow

1. **Análisis**: en Fase 0 o 1, indicar **tipo = market | custom** y **nombre** del servicio. Si es market, indicar cuál de la tabla (o “otro chart/operator”). Si es custom, indicar propósito y si se expone.
2. **Ejecución**: para **market** usar `docs/k8s/<servicio>/` con values + apply script (Helm/operator). Para **custom** usar plantilla en `workflow/services/_template/` y crear `docs/k8s/<nombre-app>/` con Deployment/Service/Ingress.
3. **Exposición**: para cualquier servicio con “Expuesto = Sí”, seguir **workflow/skills/cloudflare-https-exposure.md** tras tener el Ingress aplicado.

Referencia de orden de despliegue: `docs/08-notas-implementacion.md` §7 y `docs/plan-de-trabajo.md` §5–6.
