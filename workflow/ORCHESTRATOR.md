# Orquestador – Validación y delegación

El orquestador es el rol que **coordina** los flujos de análisis y ejecución, **valida** que cada tarea esté completada según criterios definidos y **mantiene** la tabla de aprendizaje.

## Responsabilidades

1. **Verificar** que cada step o tarea del workflow cumple sus criterios de éxito antes de marcar como completado.
2. **Delegar** tareas concretas (con contexto y criterios) y recibir el resultado para validarlo.
3. **Anotar** en `workflow/LEARNING.md` errores comunes, causas y soluciones para reutilizar en otros servicios.
4. **Impedir** avanzar al siguiente step si la validación falla; en ese caso devolver para corrección o documentar excepción.

## Criterios de validación por tipo de tarea

| Tipo de tarea        | Criterio de “completado” (ejemplos) |
|----------------------|--------------------------------------|
| YAML del servicio    | **Auditor** ha pasado (checklist producción, incl. webhooks/URLs sin localhost); luego resumen presentado al usuario; usuario **acepta**; entonces commit; comando de validación en `workflow/services/<servicio>/steps.md`. Si el auditor falla, iterar (corregir y re-auditar) antes de presentar al usuario. |
| Script de apply      | Script ejecutado sin error; recursos creados/actualizados (e.g. `kubectl get` muestra lo esperado). |
| Manifest/Helm        | YAML cumple reglas de `.cursor/rules/k8s-yaml-prod.mdc`; sin `:latest`; recursos, probes y securityContext definidos. |
| Documentación        | `docs/plan-de-trabajo.md` o `08-notas-implementacion.md` actualizados según la regla de documentación. |
| Paso de análisis     | Dependencias, orden, requisitos BDD/NFS/Vault (si aplica) y riesgos documentados; bloque listo para ejecución. |
| Servicio desplegado  | Pods `Running`, PVCs (si aplica) bound; comando de validación ejecutado con éxito. |
| Secreto/Vault        | Sin credenciales en claro; uso de ExternalSecret/SecretStore o flujo documentado. |

Criterios más específicos por servicio se definen en `workflow/services/<servicio>/` (y en el plan de trabajo en `docs/`).

## Flujo de validación

1. **Delegar** la tarea con: servicio, step, archivos/scripts implicados, criterios de éxito.
2. **Recibir** el resultado (resumen, archivos modificados, salida de comandos si aplica).
3. **Comprobar** contra los criterios de la tabla anterior y los del servicio.
4. **Si OK**: marcar step completado; recordar **pull** (y commit si no se hizo); pasar al siguiente.
5. **Si falla**: indicar qué criterio no se cumple; opción de corregir o anotar en `LEARNING.md` y ajustar el flujo.

## Tabla de aprendizaje

La tabla de aprendizaje vive en **`workflow/LEARNING.md`**. El orquestador debe:

- Añadir una entrada cuando un error se repita o sea útil para otros servicios.
- Incluir: **servicio/área**, **error o síntoma**, **causa**, **solución** y, si aplica, **referencia** (doc o script).

No hace falta anotar cada fallo puntual; priorizar los que ayuden a no repetir errores en futuros despliegues.

## Referencias que el orquestador debe conocer

- `docs/plan-de-trabajo.md` – orden y checks del plan.
- `docs/08-notas-implementacion.md` – gotchas y decisiones.
- `.cursor/rules/k8s-yaml-prod.mdc` – reglas de manifests productivos.
- `.cursor/rules/documentation-discipline.mdc` – actualización de docs.
- `workflow/RULES.md` – pull post-step, prompting, iterativo, auditor.
- `workflow/audit/checklist-production.md` – checklist del auditor.
- `workflow/skills/webhooks-and-public-urls.md` – dominio cld-lf.com, nunca localhost en webhooks/URLs.

## Auditor (agente/workflow)

- El **auditor** (`workflow/audit/`) valida la configuración generada **antes** de presentarla al usuario. Comprueba: estándares de producción y **webhooks/URLs sin localhost** (`https://<subdominio>.cld-lf.com`). Si hay fallos, se corrige y se re-ejecuta hasta que pase. Solo tras aprobación del auditor se presenta el resumen al usuario.

## Uso por agentes/IA

Cuando un agente actúe como orquestador:

1. Cargar este archivo y `workflow/RULES.md` y `workflow/LEARNING.md`.
2. Para cada step: emitir la tarea delegada con criterios de éxito, luego evaluar el resultado con la tabla de criterios y el checklist del servicio.
3. Actualizar `LEARNING.md` cuando se identifique un patrón de error reutilizable.
4. Recordar al ejecutor la regla de **pull al completar el step**.
