# Service: Gitea

## Metadata

| Field | Value |
|-------|--------|
| **Service name** | gitea |
| **Type** | **market** (Git service - Helm chart from gitea-charts) |
| **Namespace** | `platform` |
| **Exposed (HTTPS)** | Yes. Cloudflare Tunnel + `gitea.cld-lf.com` + Access. |
| **Plan section** | `docs/plan-de-trabajo.md` §5 (Gitea desplegado) |

## Dependencies

- **Infra**: MicroK8s, DNS, Ingress (ingress-nginx via Helm), Helm, StorageClass `nfs-storage`.
- **Services**: namespace `platform`, CloudNativePG operator, PostgreSQL (`platform-db`), Vault (for dynamic credentials).
- **External**: Cloudflare Tunnel (`home-microk8s`), Access app, DNS (`gitea.cld-lf.com`).

**Order**: This service is deployed **after** PostgreSQL + Vault (with database engine configured) and **before** ArgoCD.

## Docs and manifests

- Manifests/scripts: `docs/k8s/gitea/`
- Apply script: `docs/k8s/gitea/apply-gitea-platform.sh`
- Values file: `docs/k8s/gitea/values-gitea-prod.yaml`

## Security and standards

- Secret management: Database password via Kubernetes Secret (initially); roadmap to Vault ExternalSecret.
- Compliance: `.cursor/rules/k8s-yaml-prod.mdc` (versioned image, resources, probes, securityContext).
- Webhooks/URLs: `ROOT_URL` = `https://gitea.cld-lf.com` (never localhost).

## Execution

See **steps.md** for the ordered list of steps. Each step must be validated by the orchestrator before proceeding; after each completed step, run **pull** per `workflow/RULES.md`.
