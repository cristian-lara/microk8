# Service: <SERVICIO>

Template for a new service. Replace `<SERVICIO>`, `<NAMESPACE>`, and placeholders with real values.

## Metadata

| Field | Value |
|-------|--------|
| **Service name** | <SERVICIO> |
| **Type** | **market** (existing: postgres, vault, gitea, argocd, woodpecker, harbor, …) or **custom** (own app). See `workflow/skills/service-catalog.md`. |
| **Namespace** | <NAMESPACE> (e.g. `platform` for platform components, or `apps`, `n8n`, etc. for business apps) |
| **Exposed (HTTPS)** | Yes / No. If Yes: Cloudflare Tunnel + subdomain + Access (no port forwarding). See `workflow/skills/cloudflare-https-exposure.md`. |
| **Plan section** | Link to `docs/plan-de-trabajo.md` section (e.g. §5 PostgreSQL, §5 Vault) |

## Dependencies

- List infra and service dependencies (e.g. namespace, NFS StorageClass, PostgreSQL, Vault).
- Order: this service is deployed **after** … and **before** …

## Docs and manifests

- Manifests/scripts: `docs/k8s/<servicio>/`
- Apply script(s): `docs/k8s/<servicio>/apply-*.sh` (or equivalent)

## Security and standards

- Secret management: Vault / ExternalSecret (no credentials in plain text in YAML).
- Compliance: `.cursor/rules/k8s-yaml-prod.mdc` (versioned image, resources, probes, securityContext).

## Execution

See **steps.md** for the ordered list of steps. Each step must be validated by the orchestrator before proceeding; after each completed step, run **pull** per `workflow/RULES.md`.
