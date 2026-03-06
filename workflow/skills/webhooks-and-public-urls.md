# Skill: Webhooks y URLs públicas (nunca localhost)

**Regla estricta:** En producción, las aplicaciones que exponen webhooks, callbacks o URLs que deban ser accesibles desde fuera (otras apps, servicios externos, Git, CI) **nunca** deben usar `localhost`, `127.0.0.1` ni IPs privadas en las variables de entorno del deploy ni en los values/manifests. El **dominio base** es siempre **cld-lf.com**; el **subdominio** se define por servicio.

## Dominio y subdominio

- **Dominio base:** `cld-lf.com` (fijo en este proyecto).
- **Subdominio por servicio:** según el servicio (ej. `gitea` → `gitea.cld-lf.com`, `n8n` → `n8n.cld-lf.com`, `app1` → `app1.cld-lf.com`).
- **URL pública del servicio:** `https://<subdominio>.cld-lf.com` (HTTPS, expuesto vía Cloudflare Tunnel).

## Investigación obligatoria

Antes de dar por cerrada la configuración de un servicio:

1. **Investigar si la aplicación tiene webhooks o callbacks** que deban ser expuestos (ej. Gitea webhooks para CI, n8n webhook URLs, ArgoCD callback, OAuth redirect_uri, notificaciones, etc.).
2. **Identificar variables de entorno o opciones de configuración** que definan:
   - URL raíz de la app (ROOT_URL, PUBLIC_URL, SITE_URL, etc.).
   - URL de webhook o callback (WEBHOOK_URL, CALLBACK_URL, etc.).
   - Cualquier endpoint que servicios externos deban llamar.
3. **Asegurar** que todas esas URLs estén configuradas con `https://<subdominio>.cld-lf.com` (y path si aplica), **nunca** con `http://localhost`, `http://127.0.0.1`, `http://microk8server:...` ni IP privada.

## Prohibido en producción

En manifests, `values.yaml` de producción y variables de entorno del Deployment/StatefulSet/Helm:

- `localhost`, `127.0.0.1`
- IPs privadas (192.168.x.x, 10.x.x.x) como host de URLs públicas
- Nombres internos de servicio (ej. `http://gitea.platform.svc:3000`) como URL que un cliente externo deba usar

## Correcto

- `https://gitea.cld-lf.com` (para Gitea)
- `https://n8n.cld-lf.com` (para n8n)
- `https://argo.cld-lf.com` (para ArgoCD)
- `https://<subdominio>.cld-lf.com/webhook` (o el path que use la app)

El auditor del workflow debe **rechazar** cualquier configuración que contenga localhost/127.0.0.1 en URLs públicas o variables de webhook/callback antes de pasar a la aprobación del usuario.

## Referencias

- `.cursor/rules/k8s-yaml-prod.mdc` §9 (URLs externas, callbacks y webhooks).
- `workflow/audit/checklist-production.md` (auditor).
- `docs/08-notas-implementacion.md` (decisiones de identidad y acceso).
