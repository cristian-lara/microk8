# Service: Keycloak

## Metadata

| Field | Value |
|-------|--------|
| **Service name** | keycloak |
| **Type** | **market** (Identity Provider - Bitnami Helm chart) |
| **Namespace** | `platform` |
| **Exposed (HTTPS)** | Yes. Cloudflare Tunnel + `keycloak.cld-lf.com` + Access (MFA estricto). |
| **Plan section** | `docs/plan-de-trabajo.md` §5b (Identity Provider centralizado) |

## Dependencies

- **Infra**: MicroK8s, DNS, Ingress (ingress-nginx via Helm), Helm, StorageClass `nfs-storage`.
- **Services**: namespace `platform`, CloudNativePG operator, PostgreSQL (`platform-db`).
- **External**: Cloudflare Tunnel (`home-microk8s`), Access app con MFA, DNS (`keycloak.cld-lf.com`).

**Order**: This service is deployed **after** Gitea (auth local) and **before** integrating apps with SSO.

## Docs and manifests

- Manifests/scripts: `docs/k8s/keycloak/`
- Apply script: `docs/k8s/keycloak/apply-keycloak-platform.sh`
- Values file: `docs/k8s/keycloak/values-keycloak-prod.yaml`

## Security and standards

- Secret management: Admin password via Kubernetes Secret; DB password via Secret.
- Compliance: `.cursor/rules/k8s-yaml-prod.mdc` (versioned image, resources, probes, securityContext).
- **Crítico**: Keycloak es el IdP; proteger con Access + MFA estricto.

## Post-deployment tasks

1. Crear realm `cld-lf`
2. Configurar Identity Provider externo (Google) si se desea federación
3. Crear clients OIDC para cada app (gitea, argocd, vault, etc.)
4. Configurar roles: `admin`, `developer`, `viewer`
5. Crear usuarios iniciales

## Execution

See **steps.md** for the ordered list of steps.
