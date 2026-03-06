# Validación del workflow (vista arquitecto DevOps)

Este documento resume la **coherencia** del workflow con el plan y las decisiones de la plataforma, para permitir crear servicios de forma profesional sin conflictos.

## 1. Orden de dependencias (sin conflictos)

- **Plan y 08-notas §7** están alineados: Helm → Ingress vía Helm → namespace `platform` → **Operador CloudNativePG** → **PostgreSQL** → **Vault** → Vault+PostgreSQL (motor database) → Gitea → ArgoCD → resto.
- PostgreSQL **antes** de Vault (Vault usa la DB para credenciales dinámicas). Operador CloudNativePG **antes** de aplicar el Cluster PostgreSQL.
- El flujo de análisis (Fase 1) pide comprobar este orden; el flujo de ejecución y `workflow/services/<servicio>/steps.md` deben respetarlo.

## 2. Flujo profesional end-to-end

| Fase | Acción | Quién valida |
|------|--------|----------------|
| Análisis | Tipo (market/custom), expuesto, BDD/NFS/Vault, webhooks (subdominio cld-lf.com) | Orquestador (criterios en ORCHESTRATOR.md) |
| Crear YAML | Manifests/values del servicio | — |
| **Auditor** | Checklist producción (imagen, resources, probes, securityContext, secretos, **webhooks sin localhost**) | Auditor; si falla → iterar hasta pasar |
| Usuario | Resumen → aceptar o iterar | Usuario |
| Commit | Solo tras aceptar; comando de validación en steps.md | RULES.md |
| Apply en cluster | Script/Helm en VM | Orquestador (pods Running, etc.) |
| Post-step | Pull (y commit si aplica) | RULES.md |
| Cierre | Actualizar plan-de-trabajo.md y 08-notas si aplica; LEARNING.md si hay error reutilizable | Documentación |

No se presenta nada al usuario sin haber pasado el auditor. No se hace commit del YAML sin aceptación explícita.

## 3. Referencias unificadas (sin reglas externas borradas)

- Los estándares de producción (YAML, secretos, probes, securityContext) viven en **workflow/audit/checklist-production.md** y **workflow/skills/best-practices.md**. No se depende de `.cursor/rules/k8s-yaml-prod.mdc` ni `documentation-discipline.mdc` (eliminados); el workflow es autónomo.
- La única regla de Cursor es **.cursor/rules/workflow.mdc**: respetar siempre este workflow.

## 4. Ingress y Helm

- Ingress se instala **vía Helm** (ingress-nginx), no con addon de MicroK8s. Documentado en `docs/02-microk8s-bootstrap.md` y `docs/08-notas-implementacion.md` §3b.
- En el plan, **Addon Helm** aparece antes de **Ingress vía Helm** (orden correcto: habilitar Helm antes de instalar charts).

## 5. Webhooks y URLs

- Regla estricta: investigar si la app tiene webhooks/callbacks; **nunca** localhost/127.0.0.1 en variables de entorno del deploy; siempre `https://<subdominio>.cld-lf.com` (dominio **cld-lf.com**). El auditor rechaza si no se cumple.

## 6. Namespace y servicios

- `platform`: solo componentes de plataforma (PostgreSQL, Vault, Gitea, ArgoCD, CI, Registry). Apps de negocio en otros namespaces (`apps`, `n8n`, etc.). Coherente en plan, 08-notas §8, audit checklist y skills.

## 7. Checklist rápido para nuevos servicios

- [ ] Análisis ejecutado (tipo, dependencias, orden, BDD/NFS/Vault, webhooks).
- [ ] Directorio `workflow/services/<servicio>/` con README y steps.md (y analysis.md si aplica).
- [ ] Manifests/values creados; **auditor** pasado (sin localhost en URLs/webhooks).
- [ ] Resumen presentado al usuario; aceptación recibida.
- [ ] Commit con comando de validación documentado en steps.md; pull.
- [ ] Apply en cluster; validación (pods, PVCs, HTTPS si expuesto).
- [ ] Plan y 08-notas actualizados si aplica; LEARNING.md si hay error reutilizable.

---

**Conclusión:** El workflow está alineado con el plan, el orden de instalación en 08-notas §7, Ingress vía Helm, webhooks con cld-lf.com y auditor antes del usuario. No hay dependencias de reglas de Cursor eliminadas; todo lo necesario está en `workflow/` y `docs/`.

---

## 8. Redeploy, persistencia y arranque tras apagado

- **Persistencia:** Todos los componentes con estado (PostgreSQL, Vault, Gitea, etc.) usan **PVCs con `nfs-storage`** (NFS en Synology). Los datos viven en el NAS; no se pierden al reiniciar pods o VM.
- **Redeploy seguro:** Re-ejecutar scripts de apply (`apply-postgres-platform.sh`, `apply-vault-platform.sh`, etc.) o `helm upgrade` **no borra** los PVCs. Es seguro para actualizar manifiestos; los datos siguen en NFS. No usar `helm uninstall` ni borrar PVCs/namespaces con datos sin backup.
- **Tras apagado:** La VM y MicroK8s arrancan; los pods vuelven a montar los mismos PVCs; PostgreSQL y el resto levantan con datos intactos. **Vault** puede quedar **sealed** tras reboot y requerir **unseal** manual (o auto-unseal si está configurado).
- Detalle completo: `docs/08-notas-implementacion.md` §10.
