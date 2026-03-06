# Skills – Capacidades del workflow

Conjunto de **skills** (conocimientos y checklists) que el workflow usa para desplegar tanto **servicios de mercado** (PostgreSQL, Vault, Gitea, ArgoCD, Woodpecker, Harbor, etc.) como **servicios custom**, con mejores prácticas y **salida HTTPS sin port forwarding** vía Cloudflare.

## Skills disponibles

| Skill | Uso | Cuándo cargar |
|-------|-----|----------------|
| **[cloudflare-https-exposure.md](cloudflare-https-exposure.md)** | Exposición externa: Tunnel, Public Hostname, Access, DNS. HTTPS en 443, sin abrir puertos. | Todo servicio que se exponga a internet (vault, argo, gitea, apps custom, etc.). |
| **[service-catalog.md](service-catalog.md)** | Catálogo: servicios de mercado (postgres, vault, gitea, argocd, woodpecker, harbor) vs servicios custom. Checklist por tipo. | Al analizar o crear un nuevo servicio; para saber si usar Helm/chart conocido o plantilla custom. |
| **[best-practices.md](best-practices.md)** | Mejores prácticas consolidadas: YAML productivo, secretos, probes, securityContext, red, TLS. | Siempre que se generen o revisen manifests. |
| **[webhooks-and-public-urls.md](webhooks-and-public-urls.md)** | **Webhooks y URLs públicas**: investigar si la app tiene webhooks/callbacks; **nunca** localhost/127.0.0.1 en env del deploy; siempre `https://<subdominio>.cld-lf.com` (dominio **cld-lf.com**). | En análisis (¿tiene webhooks?) y en auditor (validar que no haya localhost). |

## Servicios que el workflow debe poder desplegar

- **De mercado (existentes):** PostgreSQL (CloudNativePG), Vault, Gitea, ArgoCD, Woodpecker CI, Harbor (registry), y otros que existan en el ecosistema (ej. n8n, Redis, etc.).
- **Custom:** aplicaciones propias (Dockerfile/imagen propia), APIs, frontends, workers; mismos estándares de seguridad y exposición.

En todos los casos:

- Aplicar **mejores prácticas** (best-practices.md y `.cursor/rules/k8s-yaml-prod.mdc`).
- Si el servicio tiene interfaz web o API pública: **salida HTTPS con Cloudflare** (cloudflare-https-exposure.md): Tunnel + subdominio + Access, sin port forwarding.

## Flujo

1. **Análisis**: clasificar servicio como **market** o **custom** (service-catalog); definir BDD/NFS/Vault (si aplica); definir si **se expone** → aplicar skill Cloudflare.
2. **Ejecución**: crear YAML según tipo (Helm/CRD para market, Deployment/Service para custom); resumen → usuario acepta → commit; apply; si se expone, seguir pasos de cloudflare-https-exposure (Ingress, Public Hostname, Access, DNS).
3. **Validación**: pods Running; si expuesto, comprobar `https://<subdominio>.cld-lf.com` con Access.
