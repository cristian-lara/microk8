# Reglas del workflow

Reglas que aplican a todos los flujos (análisis y ejecución) y a la actuación del orquestador.

## 1. Git: pull al completar un step/tarea

- **Cada vez que se considere completado un step o tarea** del flujo de ejecución (o un bloque coherente del análisis), se debe:
  1. Hacer **commit** de los cambios asociados a ese step (mensaje en Conventional Commits).
  2. Hacer **pull** desde `origin` (o la remota principal) para traer posibles cambios de otros flujos o colaboradores.
  3. Resolver conflictos si los hay antes de continuar al siguiente step.
- No acumular muchos steps sin pull; el intervalo recomendado es **un pull por step completado y validado**.

### Commit del YAML del servicio (solo tras aceptación del usuario)

- Cuando se **crean o modifican** los manifests/values de un servicio, **no** hacer commit hasta que el usuario **confirme explícitamente** que está de acuerdo con el resumen de configuraciones (ver flujo de ejecución: "Después de crear el YAML del servicio").
- Tras el **aceptar** del usuario: commit, indicar el **comando de validación** del servicio (para comprobar que está corriendo correctamente tras el apply) y hacer pull. El comando de validación debe estar documentado en `workflow/services/<servicio>/steps.md`.

## 2. Mejores prácticas de prompting (para agentes/IA)

- **Contexto previo**: Antes de pedir análisis o ejecución, incluir:
  - Objetivo del step (qué se quiere lograr).
  - Servicio o componente afectado y namespace.
  - Referencia a `docs/plan-de-trabajo.md` y, si aplica, a `docs/08-notas-implementacion.md`.
- **Instrucciones claras**: Una tarea por prompt o por step; evitar listas largas sin orden.
- **Criterios de éxito**: Indicar qué debe cumplirse para dar el step por completado (ej. “pod Running”, “script ejecutado sin error”).
- **Salida estructurada**: Pedir resumen de lo hecho, archivos tocados y cualquier riesgo o excepción.

## 3. Enfoque iterativo y auditor

- El flujo es **iterativo**: se avanza por pasos pequeños, cada uno validado antes del siguiente.
- Existe un **auditor** implícito en el proceso:
  - El orquestador comprueba que el resultado del step cumple los criterios definidos.
  - Si no se cumple, se corrige en la misma iteración (o se anota en `LEARNING.md` y se ajusta el flujo).
- No se considera completado un step hasta que el orquestador (o el checklist de validación) lo marque como OK.

## 4. Múltiples archivos y delegación

- Los workflows **pueden estar repartidos en varios archivos** (por ejemplo: análisis por fases, ejecución por tipo de recurso).
- Tareas específicas se **delegarán** con instrucciones autocontenidas:
  - Incluir referencia al servicio, al step y a los criterios de validación.
  - El orquestador recibe el resultado y valida; si es correcto, se pasa al siguiente step; si no, se devuelve para corrección o se registra en la tabla de aprendizaje.

## 5. Seguridad y entorno productivo

- Todos los pasos deben respetar:
  - Checklist de producción (`workflow/audit/checklist-production.md`) y mejores prácticas (`workflow/skills/best-practices.md`): imágenes versionadas, recursos, probes, securityContext, secretos desde Vault.
  - Ninguna credencial en claro en manifests ni en `values.yaml` de producción.
  - Clasificación correcta namespace: `platform` para componentes de plataforma; apps de negocio en otros namespaces.
  - **Webhooks y URLs públicas**: investigar si la app tiene webhooks/callbacks; nunca `localhost` ni `127.0.0.1` en variables de entorno del deploy; siempre `https://<subdominio>.cld-lf.com` (dominio **cld-lf.com**). Ver `workflow/skills/webhooks-and-public-urls.md`.

## 6. Auditor antes del usuario

- Antes de presentar el resumen al usuario, debe ejecutarse el **auditor** (`workflow/audit/`): valida la configuración contra el checklist de producción (incluido webhooks/URLs sin localhost). Si el auditor falla, **iterar** (corregir y re-auditar) hasta que pase; solo entonces presentar al usuario. Ver `workflow/execution/flow-execution.md`.

## 7. Documentación

- Tras cambios que afecten infraestructura o seguridad, actualizar:
  - `docs/plan-de-trabajo.md` (checks correspondientes).
  - `docs/08-notas-implementacion.md` si hay problemas, soluciones o decisiones nuevas.
- Los mensajes de commit deben seguir Conventional Commits; si hay cambios de docs, reflejarlo en el tipo o scope (ej. `docs: ...` o `chore(docs): ...`).
