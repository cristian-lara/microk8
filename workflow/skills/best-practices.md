# Skill: Mejores prácticas (consolidado)

Checklist de mejores prácticas que aplican a **todos** los servicios (market y custom) en este homelab productivo. Complementa `.cursor/rules/k8s-yaml-prod.mdc`.

## 1. Imágenes y despliegue

- **Nunca** usar tag `:latest`. Siempre imagen versionada (ej. `postgresql:16.3`, `myapp:v1.2.3`).
- Workloads críticos: al menos `replicas: 2` cuando tenga sentido (HA).
- `revisionHistoryLimit`: 3–5 para no acumular muchos ReplicaSets.

## 2. Recursos

- **Todos** los contenedores: `resources.requests.cpu`, `resources.requests.memory`, `resources.limits.cpu`, `resources.limits.memory`.
- No dejar recursos sin límites en producción.

## 3. Seguridad de pods

- `securityContext` a nivel pod y/o contenedor:
  - `runAsNonRoot: true`
  - `runAsUser` / `runAsGroup` distintos de 0 cuando sea posible
  - `readOnlyRootFilesystem: true` salvo justificación
  - `allowPrivilegeEscalation: false`
  - `privileged: false`
  - `capabilities.drop: ["ALL"]` y añadir solo las estrictamente necesarias
- Evitar `hostNetwork`, `hostPID`, `hostIPC` salvo casos justificados y documentados.
- Evitar `hostPath`; si es imprescindible, documentar motivo e impacto.

## 4. Salud y disponibilidad

- **livenessProbe** y **readinessProbe** en todos los contenedores.
- **startupProbe** para servicios que tarden en arrancar.
- Timeouts y períodos razonables para evitar reinicios en bucle.
- Para servicios críticos: **PodDisruptionBudget**.

## 5. Red

- **Service** tipo **ClusterIP** por defecto.
- Evitar NodePort en producción; exponer vía **Ingress + Cloudflare Tunnel**.
- **NetworkPolicy** con default deny y reglas mínimas necesarias.

## 6. Secretos y configuración

- **Nunca** contraseñas, tokens o API keys en claro en YAML (Secret.data, ConfigMap, values).
- Secretos desde **Vault**: ExternalSecret / SecretStore (o Vault Agent) que rellenan un Secret de K8s; el Deployment referencia ese Secret.
- Configuración no sensible en ConfigMap; sensible solo vía Vault.

## 7. TLS y tráfico externo

- Todo tráfico externo por **HTTPS/TLS** (Cloudflare termina TLS; certificados válidos).
- No certificados auto-firmados hacia el cliente final.
- **URLs de callbacks y webhooks**: siempre **dominios reales** (ej. `https://gitea.cld-lf.com`), nunca `localhost` ni IP privada en producción.

## 8. Namespaces

- **platform**: solo componentes de plataforma (Vault, PostgreSQL, Gitea, ArgoCD, CI, Registry, observabilidad).
- **Apps de negocio**: namespaces separados (`apps`, `n8n`, `prod-*`, etc.); no desplegar apps de negocio en `platform`.

## 9. Documentación y excepciones

- Cualquier excepción a estas reglas: comentario en el YAML con motivo, riesgo y mitigación.
- Tras cambios de infra: actualizar `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md`.

## Referencia

- Reglas completas: `.cursor/rules/k8s-yaml-prod.mdc`
- Exposición HTTPS: `workflow/skills/cloudflare-https-exposure.md`
- Catálogo de servicios: `workflow/skills/service-catalog.md`
