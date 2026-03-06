# Servicios – Un directorio por servicio

Cada servicio que se levanta o modifica en la plataforma MicroK8s tiene su propio directorio bajo `workflow/services/`, con pasos, criterios de validación y enlace al plan de trabajo.

El workflow soporta **servicios de mercado** (PostgreSQL, Vault, Gitea, ArgoCD, Woodpecker, Harbor, etc.) y **servicios custom** (aplicaciones propias). En ambos casos se aplican las mismas mejores prácticas; si el servicio se expone a internet, la salida es **HTTPS sin port forwarding** vía Cloudflare (ver `workflow/skills/cloudflare-https-exposure.md` y `workflow/skills/service-catalog.md`).

## Estructura por servicio

Cada directorio `<servicio>` (ej. `postgres`, `vault`, `gitea`, `myapp` custom) debe contener:

| Archivo | Propósito |
|---------|-----------|
| **README.md** | Nombre del servicio, namespace, dependencias, enlace a `docs/plan-de-trabajo.md` y a `docs/k8s/<servicio>/`. |
| **steps.md** | Lista de pasos de ejecución en orden: comando o script, criterio de éxito, archivos implicados. |
| **analysis.md** | (Opcional) Resumen del último análisis: dependencias, orden, riesgos. Puede generarse desde el flujo de análisis. |

No es obligatorio que todos los servicios tengan `analysis.md`; sí lo es tener pasos claros en `steps.md` y README con contexto.

## Plantilla

El directorio **`_template/`** sirve de plantilla para crear un nuevo servicio:

1. Copiar `_template/` a `workflow/services/<nombre-servicio>/`.
2. Sustituir placeholders (`<SERVICIO>`, `<namespace>`, etc.) en README y steps.
3. Añadir los pasos concretos (scripts, manifests) según `docs/plan-de-trabajo.md` y `docs/k8s/`.
4. El orquestador usará los criterios de `steps.md` para validar cada step.

## Relación con el plan de trabajo

- Los checks del plan (`docs/plan-de-trabajo.md`) corresponden a bloques o servicios; cada servicio aquí debe indicar qué checks cubre.
- Los scripts y manifests reales viven en `docs/k8s/<servicio>/`; este directorio define el **flujo** (orden, validación) y la **documentación de contexto** para el workflow.

## Roles

- **DevOps**: define y ejecuta pasos (scripts, Helm, manifests).
- **GitSecOps**: revisa secretos, RBAC, NetworkPolicy, hardening.
- **Orquestador**: valida cada step según `steps.md` y los criterios de `workflow/ORCHESTRATOR.md`, y actualiza `workflow/LEARNING.md` cuando corresponda.
