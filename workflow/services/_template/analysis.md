# Analysis summary – <SERVICIO>

Optional. Fill after running the **analysis workflow** (`workflow/analysis/flow-analysis.md`) for this service.

## Dependencies and order

- Depends on: …
- Deploy after: …
- Deploy before: …

## Persistence and secrets (Fase 1b – only if applicable)

| Requisito | ¿Aplica? | Notas |
|-----------|-----------|--------|
| **Base de datos (BDD)** | Sí / No | Si sí: qué DB, usuario, credenciales desde Vault o estáticas. |
| **NFS (volumen persistente)** | Sí / No | Si sí: StorageClass `nfs-storage`, tamaño, path/mount. |
| **Ambos (BDD + NFS)** | Sí / No | Ej. Gitea: PostgreSQL + volumen para datos. |
| **Clave/secreto en Vault** | Sí / No | Si sí: qué secreto, cómo lo consume el servicio (ExternalSecret, etc.). |

## Webhooks y URLs públicas (obligatorio si la app los usa)

- **¿La aplicación tiene webhooks, callbacks o URLs que deban ser accesibles desde fuera?** (Git, CI, OAuth, notificaciones.) Sí / No.
- Si **Sí**: subdominio asignado = `<subdominio>.cld-lf.com` (dominio base **cld-lf.com**). Variables de env/values (ROOT_URL, WEBHOOK_URL, etc.) deben usar `https://<subdominio>.cld-lf.com`; **nunca** localhost ni 127.0.0.1. Ver `workflow/skills/webhooks-and-public-urls.md`. El auditor comprobará esto.

## Security and standards checklist

- [ ] Namespace: platform vs app (correct choice)
- [ ] No credentials in plain text; Vault/ExternalSecret path defined
- [ ] Image versioned (no `:latest`)
- [ ] resources, probes, securityContext defined per k8s-yaml-prod

## Risks and exceptions

- …

## Steps for execution

(Summary or pointer to **steps.md**. Include validation command for "service running correctly".)
