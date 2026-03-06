# Flujo de análisis – Pasos

Seguir estos pasos **en orden**. Cada fase debe ser validada por el orquestador antes de pasar a la siguiente.

## Fase 0: Contexto inicial

1. **Leer fuentes de verdad**
   - `docs/plan-de-trabajo.md` – sección que afecta al servicio o bloque.
   - `docs/08-notas-implementacion.md` – gotchas y orden de instalación.
   - Si el servicio ya existe: `workflow/services/<servicio>/` y `docs/k8s/<servicio>/`.

2. **Definir alcance**
   - Nombre del servicio (ej. `postgres`, `vault`, `gitea`).
   - Objetivo: ¿nuevo despliegue, actualización, solo Ingress, solo secretos?

3. **Clasificar tipo de servicio** (usar `workflow/skills/service-catalog.md`)
   - **Market**: servicio existente en el ecosistema (PostgreSQL/CloudNativePG, Vault, Gitea, ArgoCD, Woodpecker, Harbor, n8n, etc.). Origen: Helm chart, operator o CRD.
   - **Custom**: aplicación propia (imagen propia, API, frontend). Origen: Deployment/StatefulSet desde plantilla en `workflow/services/_template/`.
   - Anotar en `workflow/services/<servicio>/analysis.md` el tipo y, si es market, cuál de la tabla del catálogo.

4. **¿Se expone externamente (internet)?**
   - Si **sí**: aplicar skill **cloudflare-https-exposure** (`workflow/skills/cloudflare-https-exposure.md`). El servicio tendrá Ingress + Public Hostname en el túnel + DNS + (recomendado) Cloudflare Access. Salida **HTTPS en 443, sin port forwarding**.
   - Si **no** (solo interno al cluster): no se crea Ingress ni Public Hostname; acceso vía ClusterIP dentro del cluster.

5. **¿La aplicación tiene webhooks o callbacks que deban exponerse?** (usar `workflow/skills/webhooks-and-public-urls.md`)
   - **Investigar siempre** si la app expone webhooks, URLs de callback, OAuth redirect_uri, o endpoints que servicios externos deban llamar (ej. Gitea webhooks para CI, n8n webhook URL, notificaciones).
   - Si **sí**: esas URLs **no** deben configurarse con `localhost`, `127.0.0.1` ni IP privada en las variables de entorno del deploy. Deben usar el **dominio real**: `https://<subdominio>.cld-lf.com` (dominio base **cld-lf.com**; el subdominio se define por servicio, ej. `gitea.cld-lf.com`, `n8n.cld-lf.com`).
   - Anotar en el análisis: subdominio asignado y que en manifests/values las variables de webhook/callback/ROOT_URL etc. usarán `https://<subdominio>.cld-lf.com`. El auditor comprobará esto antes de pasar al usuario.

**Criterio orquestador**: Está claro qué servicio/componente se analiza, si es market o custom, si se expone, si tiene webhooks/callbacks y que las URLs públicas usan subdominio cld-lf.com (nunca localhost).

---

## Fase 1: Dependencias y orden

5. **Listar dependencias**
   - Infra: MicroK8s, DNS, Ingress, Helm, StorageClass (nfs-storage).
   - Servicios: namespace `platform`, PostgreSQL, Vault, etc.
   - Externos: Cloudflare Tunnel, Access, DNS (subdominio).

4. **Orden en el plan**
   - Comprobar orden recomendado en `docs/08-notas-implementacion.md` §7 y en `docs/plan-de-trabajo.md`.
   - Anotar: “Este servicio se despliega después de X y antes de Y”.

**Criterio orquestador**: Dependencias explícitas y orden coherente con el plan.

---

## Fase 1b: Requisitos de persistencia y secretos (solo si aplica)

7. **¿Necesita base de datos (BDD)?**
   - Si el servicio consume PostgreSQL (u otra BDD): indicar qué base de datos, usuario y si usará credenciales estáticas o dinámicas desde Vault (motor database).
   - Documentar en `workflow/services/<servicio>/analysis.md` y en los pasos de ejecución (ej. crear DB, crear usuario, grant).

8. **¿Necesita NFS (volumen persistente)?**
   - Si el servicio requiere almacenamiento persistente (datos, backups, uploads): indicar StorageClass `nfs-storage`, tamaño y path/mount si aplica.
   - Si no requiere volumen, dejarlo explícito ("no requiere NFS").

9. **¿Necesita ambas (BDD y NFS)?**
   - Si aplica: documentar ambos (ej. Gitea: DB en PostgreSQL + volumen para repos y datos).

10. **¿Requiere crear clave o secreto en Vault?**
   - Si el servicio necesita credenciales (DB, API keys, certificados): indicar que se debe crear el secreto en Vault y cómo lo consumirá el servicio (ExternalSecret, Vault Agent, variable de entorno desde Secret sincronizado).
   - Si no usa secretos externos, dejarlo explícito ("no requiere Vault para este servicio").

**Criterio orquestador**: Para cada servicio queda claro, solo donde aplique: BDD sí/no, NFS sí/no, Vault sí/no, y los pasos correspondientes en la ejecución.

---

## Fase 2: Requisitos de seguridad y estándares

11. **Namespace**
   - ¿Plataforma → `platform` o app de negocio → otro namespace? (Regla: no apps de negocio en `platform`.)

12. **Secretos**
    - ¿Credenciales necesarias? Deben venir de Vault (ExternalSecret/SecretStore); nada en claro en YAML. (Coherente con Fase 1b punto 8.)

13. **Estándares YAML**
    - Imagen versionada (no `:latest`), resources (requests/limits), liveness/readiness (y startup si aplica), securityContext según `.cursor/rules/k8s-yaml-prod.mdc`.

14. **Red y exposición**
    - ClusterIP por defecto. Si el servicio se expone (Fase 0 punto 4): Ingress + Cloudflare Tunnel (Public Hostname) + DNS + Access; URLs/callbacks con dominio real (*.cld-lf.com), no localhost. Ver `workflow/skills/cloudflare-https-exposure.md`.

**Criterio orquestador**: Checklist de seguridad y estándares alineado con las reglas del repo.

---

## Fase 3: Riesgos y excepciones

15. **Riesgos**
    - Ej: dependencia de NFS, orden Vault/PostgreSQL, propagación DNS.

16. **Excepciones**
    - Si alguna regla no se puede cumplir, documentar motivo, riesgo y mitigación (como en k8s-yaml-prod §10).

**Criterio orquestador**: Riesgos identificados y excepciones documentadas.

---

## Fase 4: Entregables para ejecución

17. **Resumen para el flujo de ejecución**
    - Lista de pasos concretos (scripts a ejecutar, manifests a aplicar, orden).
    - Archivos a crear o modificar (paths).
    - Criterios de éxito por paso (para el orquestador).
    - Resumen de requisitos BDD/NFS/Vault (de Fase 1b) para que ejecución los implemente.

18. **Actualizar documentación si aplica**
    - Si el análisis revela cambios en el plan o en las notas, proponer actualización de `docs/plan-de-trabajo.md` o `docs/08-notas-implementacion.md`.

**Criterio orquestador**: El flujo de ejecución puede seguir el resumen sin ambigüedad; documentación coherente.

---

## Salida del flujo de análisis

- Un **resumen** (puede vivir en `workflow/services/<servicio>/analysis.md` o en un comentario en el issue/chat) con:
  - Servicio, namespace, dependencias, orden.
  - Requisitos de seguridad y estándares.
  - Pasos de ejecución y criterios de validación.
- Con esto se puede pasar al **flujo de ejecución** para implementar paso a paso.
