# Tabla de aprendizaje (orquestador)

Errores comunes, causas y soluciones que el orquestador y los flujos pueden reutilizar al levantar o modificar servicios. Actualizar cuando un patrón se repita o sea útil para otros servicios.

| Servicio / Área | Error o síntoma | Causa | Solución | Ref |
|-----------------|-----------------|--------|----------|-----|
| NFS / Storage   | `showmount -e` no muestra exports | NFS no habilitado o permisos no configurados en Synology | Activar NFS en File Services; carpeta compartida con NFS permissions para `192.168.50.0/24`; en VM `apt install nfs-common` | `docs/08-notas-implementacion.md` §2 |
| NFS / Storage   | PVC Pending, provisioner no crea volumen | StorageClass por defecto incorrecta o hostpath en uso | Usar `nfs-storage` como default; deshabilitar hostpath-storage en prod | `docs/08-notas-implementacion.md` §3 |
| Cloudflare      | "No DNS record found for this domain" (Access) | Falta registro DNS para el hostname | Crear registro Tunnel/CNAME para el subdominio en DNS de cld-lf.com | `docs/08-notas-implementacion.md` §4.2 |
| Cloudflare      | NXDOMAIN al abrir subdominio | Mismo que arriba | Crear CNAME/Tunnel y esperar propagación | `docs/08-notas-implementacion.md` §4.3 |
| YAML / Manifests| Rechazo por reglas de prod | Imagen `:latest`, sin resources/probes/securityContext, secretos en claro | Aplicar `.cursor/rules/k8s-yaml-prod.mdc`: versión fija, resources, probes, securityContext, Vault/ExternalSecret | `k8s-yaml-prod.mdc` |
| Vault / PostgreSQL | Vault no puede crear usuarios DB | Usuario `vault` en PostgreSQL sin CREATEROLE o sin permisos en la DB | Ejecutar `create-vault-db-user.sh` y `grant-vault-to-gitea.sh` (o equivalente) en el orden indicado | `docs/k8s/vault/vault-postgres-integration.md` |
| General         | Paso marcado OK pero otro agente no ve cambios | No se hizo pull tras el step | Hacer pull (y push si aplica) al completar cada step según `workflow/RULES.md` | `workflow/RULES.md` |
| Webhooks / URLs | Webhooks o callbacks no funcionan desde fuera; app configurada con localhost | Variables de entorno del deploy (ROOT_URL, WEBHOOK_URL, etc.) con `localhost`, `127.0.0.1` o IP privada | Siempre usar dominio real: `https://<subdominio>.cld-lf.com` (dominio base **cld-lf.com**). Investigar si la app tiene webhooks; configurar con subdominio. Auditor rechaza localhost. | `workflow/skills/webhooks-and-public-urls.md`, `workflow/audit/checklist-production.md` §6 |

---

*Nuevas filas: añadir servicio/área, descripción breve del error, causa, solución y referencia (doc o script) cuando ayude a otros servicios.*
