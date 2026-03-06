# Analysis summary – PostgreSQL (CloudNativePG)

Result of analysis workflow for this service (ref. `workflow/analysis/flow-analysis.md`).

## Dependencies and order

- **Depends on**: namespace `platform`, NFS StorageClass `nfs-storage`, MicroK8s with Helm (CloudNativePG operator must be installed).
- **Deploy after**: §1–4 of plan (VM, MicroK8s, Tunnel, Access); namespace `platform` created.
- **Deploy before**: Vault (can use same cluster for DB backend), Gitea (needs DB), ArgoCD.

## Security and standards checklist

- [x] Namespace: `platform` (platform component).
- [x] No credentials in plain text in YAML; bootstrap uses initdb with database/owner; secrets for DB users via scripts/env or Vault later.
- [x] Image versioned: `ghcr.io/cloudnative-pg/postgresql:16.3`.
- [x] resources, podSecurityContext, securityContext defined per k8s-yaml-prod.

## Risks and exceptions

- **NFS**: PVC must bind; if `nfs-storage` is not default or NFS export unavailable, PVC stays Pending (see `workflow/LEARNING.md`).
- **readOnlyRootFilesystem**: Set `true` in manifest; if the image fails to start (e.g. writes to /tmp), document in LEARNING and set to `false` with justification.

## Steps for execution

See **steps.md**. Current plan: Step 1 (namespace) done; Step 2 = apply PostgreSQL on VM.
