# Workflow – MicroK8s platform (homelab seguro)

Sistema de workflows para levantar y validar servicios en el servidor MicroK8s de forma **ordenada, comprobada y segura**. Se apoya en el [plan de trabajo](../docs/plan-de-trabajo.md) y en las reglas de documentación y YAML productivo del repo.

## Objetivo

- Poder levantar **cualquier servicio** en MicroK8s siguiendo un flujo **analizar → ejecutar → validar**.
- Soportar **servicios de mercado** (PostgreSQL, Vault, Gitea, ArgoCD, Woodpecker, Harbor, etc.) y **servicios custom** (aplicaciones propias), con las mismas mejores prácticas.
- **Salida a internet por HTTPS sin port forwarding**: todos los servicios expuestos se publican vía **Cloudflare Tunnel + subdominio + (opcional) Cloudflare Access**.
- Aplicar **mejores prácticas DevOps y GitSecOps** en un homelab productivo.
- Tener un **orquestador** que verifique que las tareas se completan correctamente.
- Mantener un **registro de aprendizaje** (errores comunes) para mejorar futuros despliegues.

## Estructura

```
workflow/
├── README.md                 # Este archivo
├── ORCHESTRATOR.md            # Rol orquestador: validación, checklist, delegación
├── RULES.md                   # Reglas: pull post-step, prompting, iterativo, auditor
├── LEARNING.md                # Tabla de aprendizaje (errores comunes por servicio)
├── skills/                    # Skills del workflow (capacidades reutilizables)
│   ├── README.md
│   ├── cloudflare-https-exposure.md   # HTTPS sin port forwarding (Tunnel, Access, DNS)
│   ├── service-catalog.md             # Servicios market vs custom (postgres, vault, gitea, …)
│   ├── best-practices.md              # Mejores prácticas consolidadas
│   └── webhooks-and-public-urls.md    # Webhooks/URLs: dominio cld-lf.com, nunca localhost
├── audit/                     # Auditor: valida config antes de presentar al usuario
│   ├── README.md
│   └── checklist-production.md        # Checklist (incl. webhooks/URLs sin localhost)
├── roles/                     # Roles expertos (DevOps, GitSecOps, Orquestador)
│   └── README.md
├── analysis/                  # Flujo de análisis
│   ├── README.md
│   └── flow-analysis.md
├── execution/                 # Flujo de ejecución
│   ├── README.md
│   └── flow-execution.md
└── services/                  # Un directorio por servicio (market o custom)
    ├── README.md
    ├── _template/             # Plantilla para nuevo servicio
    └── <servicio>/            # ej. postgres, vault, gitea, argocd, woodpecker, <custom>
```

## Flujos principales

| Flujo        | Propósito | Cuándo usarlo |
|-------------|-----------|----------------|
| **Análisis** | Entender dependencias, riesgos, orden y requisitos del servicio; validar si necesita BDD, NFS y/o clave en Vault (solo si aplica) | Antes de tocar código o manifests |
| **Ejecución** | Aplicar cambios paso a paso; tras crear YAML: resumen → confirmación usuario → iterar hasta aceptar → commit + comando de validación; luego validación y pull | Al implementar o modificar un servicio |

El **orquestador** (ver `ORCHESTRATOR.md`) coordina ambos flujos, delega tareas y comprueba que cada paso esté completado antes de continuar.

## Cómo usar

1. **Antes de trabajar en un servicio**
   - Leer `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md`.
   - Seguir el flujo de **análisis** (`workflow/analysis/`) para el servicio o bloque que vayas a tocar.

2. **Al implementar**
   - Usar el flujo de **ejecución** (`workflow/execution/`) y el directorio del servicio en `workflow/services/<servicio>/`.
   - Tras completar cada **step/tarea**: hacer **pull** (y push si aplica) según `RULES.md`.

3. **Validación**
   - El orquestador comprueba cada paso según los criterios definidos en `ORCHESTRATOR.md`.
   - Si algo falla o se aprende algo nuevo, se anota en `LEARNING.md`.

## Skills (capacidades del workflow)

Antes de analizar o ejecutar un servicio, conviene cargar los skills que apliquen:

- **[skills/cloudflare-https-exposure.md](skills/cloudflare-https-exposure.md)** – Para cualquier servicio que se exponga a internet: Ingress + Public Hostname en el túnel + DNS + Access. HTTPS en 443, sin port forwarding.
- **[skills/service-catalog.md](skills/service-catalog.md)** – Clasificación **market** (postgres, vault, gitea, argocd, woodpecker, harbor, …) vs **custom**; checklist por tipo.
- **[skills/best-practices.md](skills/best-practices.md)** – Mejores prácticas consolidadas (imagen versionada, resources, probes, securityContext, secretos desde Vault, namespaces, TLS).
- **[skills/webhooks-and-public-urls.md](skills/webhooks-and-public-urls.md)** – **Webhooks/URLs**: investigar si la app tiene webhooks; nunca localhost en env del deploy; siempre `https://<subdominio>.cld-lf.com` (dominio **cld-lf.com**).
- **[audit/](audit/)** – **Auditor**: valida la configuración contra estándares de producción (y webhooks sin localhost) **antes** de presentar al usuario; si falla, iterar hasta que pase.

## Referencias obligatorias

- [Plan de trabajo](../docs/plan-de-trabajo.md) – checklist y orden de despliegue.
- [Notas de implementación](../docs/08-notas-implementacion.md) – gotchas, orden de instalación (§7) y decisiones.
- Estándares de producción (YAML, secretos, probes, securityContext): [workflow/audit/checklist-production.md](audit/checklist-production.md) y [workflow/skills/best-practices.md](skills/best-practices.md).
- Documentación: tras cambios de infra o seguridad, actualizar `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md` (ver `workflow/RULES.md` §7).

## Roles expertos

- **DevOps**: despliegue, scripts, Helm, Kubernetes, storage, red.
- **GitSecOps**: secretos (Vault), RBAC, NetworkPolicy, hardening, sin credenciales en claro.
- **Orquestador**: validación de tareas, tabla de aprendizaje, delegación y criterios de “completado”.

Todos los workflows deben aplicarse considerando un **entorno homelab seguro/productivo**: sin `:latest`, con recursos y probes, securityContext endurecido y secretos desde Vault.

## Validación de coherencia (arquitecto DevOps)

Para comprobar que el workflow no tiene conflictos con el plan y permite crear servicios de forma profesional: **[workflow/VALIDATION.md](VALIDATION.md)** – orden de dependencias, flujo end-to-end, referencias unificadas, Ingress/Helm, webhooks y checklist para nuevos servicios.
