# Auditor – Validación antes del usuario

El **auditor** es un agente/workflow que valida que la configuración generada (manifests, values, variables de entorno) cumple los **estándares de producción** **antes** de presentar el resumen al usuario. Si encuentra fallos, **itera**: reporta los fallos, se corrigen los archivos y se vuelve a auditar hasta que pase. Solo cuando el auditor aprueba se presenta el resumen al usuario para aceptación.

## Cuándo se ejecuta

- **Después** de crear o modificar los YAML/values del servicio (Deployment, StatefulSet, Helm values).
- **Antes** de "Presentar el resumen al usuario" en el flujo de ejecución.

Flujo: **Generar YAML → Ejecutar auditor → (si falla) Corregir e iterar → (si pasa) Presentar resumen al usuario → Usuario acepta → Commit**.

## Responsabilidades del auditor

1. Revisar **todos** los manifests y values del servicio contra el checklist de producción (`workflow/audit/checklist-production.md`).
2. **Rechazar** si encuentra:
   - Imagen `:latest`, falta de resources/limits, probes o securityContext.
   - Secretos o contraseñas en claro.
   - **URLs o variables de webhook/callback con localhost, 127.0.0.1 o IP privada** (deben ser `https://<subdominio>.cld-lf.com`). Ver `workflow/skills/webhooks-and-public-urls.md`.
   - Cualquier incumplimiento de `.cursor/rules/k8s-yaml-prod.mdc`.
3. Emitir un **informe** con: OK / lista de fallos (archivo, línea o clave, descripción).
4. **Iterar**: si hay fallos, el ejecutor corrige y se vuelve a ejecutar el auditor hasta **0 fallos**.

## Criterio de aprobación

- **Aprobado**: el checklist de producción pasa sin fallos; entonces se puede presentar el resumen al usuario.
- **No aprobado**: uno o más ítems fallan; no se presenta al usuario hasta corregir y re-auditar.

## Referencias

- Checklist: `workflow/audit/checklist-production.md`.
- Webhooks/URLs: `workflow/skills/webhooks-and-public-urls.md`.
- Reglas YAML: `.cursor/rules/k8s-yaml-prod.mdc`.
