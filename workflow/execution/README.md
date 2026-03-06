# Flujo de ejecución

Workflow para **ejecutar** la implementación de un servicio (o un bloque del plan) **paso a paso**, con validación tras cada step y **pull** al completar.

## Objetivo

- Aplicar los pasos definidos tras el flujo de análisis (o los del plan de trabajo).
- Validar cada step antes de continuar (orquestador).
- Hacer **pull** (y commit si aplica) al completar cada step, según `workflow/RULES.md`.
- Ir dejando documentación y plan actualizados.

## Cuándo usarlo

- Después de haber hecho (o tener equivalente de) el flujo de análisis para el servicio.
- Al aplicar manifests, scripts de apply, configuración de Vault o Ingress.
- Al añadir un nuevo subdominio o componente en la plataforma.

## Archivos

- **flow-execution.md** – Pasos genéricos del flujo de ejecución y ciclo step → validar → pull.

El **paso actual** se deduce de `docs/plan-de-trabajo.md` (ítems sin marcar) y de `workflow/services/<servicio>/steps.md` del servicio en el que se esté trabajando.

## Regla crítica: pull post-step

Tras **cada step completado y validado**:

1. Commit de los cambios de ese step (Conventional Commits).
2. **Pull** desde la remota principal.
3. Resolver conflictos si los hay.
4. Solo entonces pasar al siguiente step.

## Validación

El orquestador usa los criterios de `workflow/ORCHESTRATOR.md` y los criterios específicos del servicio en `workflow/services/<servicio>/` para marcar un step como completado.
