# Flujo de análisis

Workflow para **analizar** un servicio o bloque del plan de trabajo antes de implementar: dependencias, orden, riesgos y requisitos.

## Objetivo

- Entender qué hay que desplegar o modificar y en qué orden.
- Identificar dependencias (otros servicios, namespaces, Vault, storage).
- **Validar, solo si aplica:** ¿necesita base de datos (BDD)?, ¿NFS para guardar datos?, ¿ambos?, ¿requiere crear clave/secreto en Vault? (Fase 1b del flujo de análisis).
- Detectar riesgos de seguridad o configuración y alinearlos con las reglas del repo (YAML productivo, secretos, namespace).
- Dejar documentado el resultado para que el flujo de ejecución pueda aplicarlo paso a paso.

## Cuándo usarlo

- Antes de crear o modificar manifests/Helm/scripts de un servicio.
- Cuando se añade un nuevo servicio al plan (nuevo directorio en `workflow/services/`).
- Cuando hay dudas sobre el orden respecto a PostgreSQL, Vault, Ingress o Cloudflare.

## Archivos

- **flow-analysis.md** – Pasos concretos del flujo de análisis y criterios de validación por fase.

## Validación

El orquestador considera completado el análisis cuando:

1. Está definido el **servicio** y su **namespace** (platform vs apps).
2. Están listadas las **dependencias** (ej. PostgreSQL, Vault, NFS, Ingress).
3. Está claro el **orden** de ejecución respecto al plan de trabajo.
4. Se han anotado **riesgos o excepciones** y cómo se mitigan.
5. Los requisitos de **seguridad** (secretos, RBAC, probes, resources) están alineados con las reglas del repo.
