# Roles expertos del workflow

Roles que intervienen en los flujos de análisis y ejecución. El orquestador delega en ellos y valida los resultados.

## DevOps

- **Responsabilidad**: Despliegue, scripts de apply, Helm, Kubernetes (manifests, StorageClass, PVCs), red (Service, Ingress), almacenamiento (NFS).
- **Referencias**: `docs/plan-de-trabajo.md`, `docs/k8s/**/`, `.cursor/rules/k8s-yaml-prod.mdc` (recursos, probes, replicas).
- **Entregables**: Scripts ejecutables, manifests/values que cumplan las reglas de producción (imagen versionada, resources, probes, securityContext).

## GitSecOps

- **Responsabilidad**: Secretos (Vault, ExternalSecret, SecretStore; nunca credenciales en claro en YAML), RBAC, NetworkPolicy, hardening de pods (securityContext), URLs y callbacks (dominios reales, no localhost en producción).
- **Referencias**: `.cursor/rules/k8s-yaml-prod.mdc` (secciones seguridad, secretos, TLS), `docs/k8s/vault/`, `docs/08-notas-implementacion.md` (identidad y acceso).
- **Entregables**: Configuración de secretos vía Vault, revisión de manifests desde el punto de vista de seguridad, y documentación de excepciones si alguna regla no se cumple.

## Orquestador

- **Responsabilidad**: Validar que cada step/tarea cumple sus criterios, delegar tareas con contexto y criterios de éxito, mantener la tabla de aprendizaje (`workflow/LEARNING.md`), recordar la regla de **pull** tras cada step completado.
- **Referencias**: `workflow/ORCHESTRATOR.md`, `workflow/RULES.md`, `workflow/LEARNING.md`, y los `workflow/services/<servicio>/steps.md`.

Cuando un agente o persona actúe como orquestador, debe cargar `ORCHESTRATOR.md` y `RULES.md` y aplicar los criterios de validación antes de marcar un step como completado.
