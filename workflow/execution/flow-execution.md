# Flujo de ejecución – Pasos

Ciclo **step → ejecutar → validar → pull → siguiente step**. No avanzar hasta que el orquestador valide.

## Antes de empezar

1. Tener el **resultado del análisis** (o el plan equivalente) para el servicio: pasos, archivos, criterios de éxito.
2. Confirmar que las **dependencias** del servicio están cumplidas (ej. namespace `platform` existe, PostgreSQL o Vault ya desplegados si aplica).
3. Tener **acceso** al repo y al cluster (kubectl/microk8s, Helm) según corresponda.

---

## Después de crear el YAML del servicio (auditor → confirmación con el usuario)

Cuando se **crean o modifican** los manifests/values del servicio (Deployment, StatefulSet, Helm values, etc.):

1. **Generar** los manifests/values y un borrador de resumen (incluir en el resumen las URLs/webhooks con subdominio cld-lf.com, nunca localhost).

2. **Ejecutar el auditor** (`workflow/audit/`): validar la configuración contra el checklist de producción (`workflow/audit/checklist-production.md`), en particular:
   - Estándares de producción (imagen versionada, resources, probes, securityContext, secretos desde Vault).
   - **Webhooks y URLs públicas**: investigar si la app tiene webhooks/callbacks; comprobar que **ninguna** variable de entorno ni opción use `localhost`, `127.0.0.1` ni IP privada; deben usar `https://<subdominio>.cld-lf.com` (dominio base **cld-lf.com**). Ver `workflow/skills/webhooks-and-public-urls.md`.
   - Si el auditor **falla**: listar fallos (archivo, ítem); corregir manifests/values y **volver a ejecutar el auditor** hasta que **pase** (iterar). No presentar al usuario hasta que el auditor apruebe.
   - Si el auditor **pasa**: continuar al punto 3.

3. **Generar el resumen** con las principales configuraciones (incluyendo **URLs/webhooks** configurados con subdominio cld-lf.com, nunca localhost) y **presentar el resumen al usuario** para confirmación explícita.

4. **Iterar con el usuario** hasta que esté satisfecho: si pide cambios, ajustar y volver a pasar por el auditor si se tocaron manifests/values; **no hacer commit** hasta que el usuario **acepte**.

5. **Cuando el usuario dé el aceptar**:
   - Hacer **commit** de los cambios del servicio (mensaje Conventional Commits, ej. `feat(postgres): add prod manifest with securityContext`).
   - Indicar el **comando para validar** que el servicio está corriendo correctamente (ej. `microk8s kubectl get pods -n platform -l app=platform-db` o el script `docs/k8s/scripts/validate-platform.sh`). Ese comando debe quedar documentado en `workflow/services/<servicio>/steps.md` en la fila de validación.
   - Según `workflow/RULES.md`: hacer **pull** y luego continuar con la ejecución del apply en el cluster cuando corresponda.

**Resumen del flujo:** Generar YAML → **Auditor** (si falla, corregir e iterar hasta que pase) → Presentar resumen al usuario → Usuario acepta → Commit. El commit del YAML **solo** tras aceptación explícita. La validación en cluster se hace después de aplicar en la VM/cluster.

---

## Ciclo por step

Para **cada** paso de implementación (cada script, cada apply, cada bloque lógico):

### 1. Ejecutar el step

- Ejecutar el comando o aplicar el manifest/Helm indicado en el plan o en `workflow/services/<servicio>/`.
- Ejemplo: `chmod +x docs/k8s/postgres/apply-postgres-platform.sh && ./docs/k8s/postgres/apply-postgres-platform.sh`
- Registrar salida (stdout/stderr) si hay error o para evidencias.

### 2. Comprobar resultado

- Comprobar que el recurso existe y está en el estado esperado (ej. `microk8s kubectl get pods -n platform`, `kubectl get pvc -n platform`).
- Revisar que los manifests/values cumplan el checklist de producción (`workflow/audit/checklist-production.md`): imagen versionada, resources, probes, securityContext, sin secretos en claro.

### 3. Validación por el orquestador

- El orquestador comprueba contra los criterios de `workflow/ORCHESTRATOR.md` y los del servicio.
- Si **OK**: marcar step completado y seguir al punto 4.
- Si **falla**: indicar qué criterio no se cumple; corregir y repetir 1–2, o anotar en `workflow/LEARNING.md` y ajustar el flujo.

### 4. Commit y pull (post-step)

- **Commit** de los cambios asociados a este step (mensaje Conventional Commits).
- **Pull** desde `origin` (o la remota principal).
- Resolver conflictos si los hay.
- Continuar al **siguiente step** solo después de esto.

---

## Orden típico por tipo de servicio (referencia)

Alineado con `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md`:

1. Namespace (si no existe).
2. StorageClass / PVCs si el servicio requiere volumen.
3. Secretos (Vault/ExternalSecret o flujo documentado); nunca en claro en YAML.
4. Deployment/StatefulSet/Helm del servicio.
5. Service (ClusterIP).
6. **Ingress** (si el servicio se expone externamente).
7. **Exposición HTTPS con Cloudflare (sin port forwarding)** – solo si aplica (ver abajo).
8. Validación final (pods Running, PVCs bound; si expuesto: `https://<subdominio>.cld-lf.com`).

Los pasos concretos por servicio deben estar en `workflow/services/<servicio>/` (y en `docs/k8s/<servicio>/`).

---

## Exposición HTTPS con Cloudflare (sin port forwarding)

Para **cualquier servicio que se exponga a internet** (Vault, ArgoCD, Gitea, Woodpecker, apps custom con UI/API pública), seguir el skill **workflow/skills/cloudflare-https-exposure.md**:

1. **Ingress** en el cluster (host = subdominio, ej. `vault.cld-lf.com`); aplicar manifest o script `apply-ingress-*.sh`.
2. **Public Hostname** en el túnel (Cloudflare Zero Trust): añadir ruta para el subdominio → URL del backend (ej. `http://127.0.0.1:80` o la del Ingress).
3. **DNS**: registro CNAME o Tunnel para el subdominio apuntando al túnel.
4. **Cloudflare Access** (recomendado): aplicación para el subdominio con política (allowlist, MFA para sensibles).
5. **Validación**: abrir `https://<subdominio>.cld-lf.com` y comprobar HTTPS sin port forwarding.

Documentar en `docs/06-subdominios-hostnames.md` (o equivalente) el mapping hostname → servicio:puerto.

---

## Al finalizar todos los steps del servicio

- Actualizar **docs/plan-de-trabajo.md**: marcar checks correspondientes.
- Actualizar **docs/08-notas-implementacion.md** si hubo problemas o decisiones nuevas.
- Si aparece un error reusable, el orquestador debe añadirlo a **workflow/LEARNING.md**.

---

## Redeploy y persistencia

- **Redeploy** (volver a ejecutar los scripts de apply o `helm upgrade`) es **seguro**: los datos están en **PVCs con nfs-storage** (NFS); no se borran al re-aplicar. No usar `helm uninstall` ni eliminar PVCs/namespaces con datos sin backup.
- **Tras apagar la VM o el cluster:** al arrancar, los pods vuelven a montar los mismos PVCs; los datos persisten. **Vault** puede quedar sealed y requerir **unseal** tras un reboot. Ver `docs/08-notas-implementacion.md` §10.
