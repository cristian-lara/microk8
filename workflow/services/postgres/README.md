# Service: PostgreSQL (CloudNativePG)

## Metadata

| Field | Value |
|-------|--------|
| **Service name** | postgres (platform-db via CloudNativePG) |
| **Namespace** | `platform` |
| **Plan section** | `docs/plan-de-trabajo.md` §5 – PostgreSQL (CloudNativePG) |

## Dependencies

- Namespace `platform` must exist.
- NFS StorageClass (`nfs-storage`) as default; no hostpath in production.
- MicroK8s with Helm, DNS, Ingress enabled.

## Docs and manifests

- Manifests/scripts: `docs/k8s/postgres/`
- Apply: `docs/k8s/postgres/apply-postgres-platform.sh`
- Optional: `docs/k8s/postgres/create-gitea-db.sh`, `create-vault-db-user.sh`, `grant-vault-to-gitea.sh` (see Vault integration).

## Security and standards

- Secret management: DB credentials via env or Vault later; not in plain text in YAML.
- Compliance: `.cursor/rules/k8s-yaml-prod.mdc` (image versioned, resources, probes, securityContext).
- Storage: PVCs use `nfs-storage`.

## Execution

See **steps.md**. After each completed step: commit and **pull** per `workflow/RULES.md`.
