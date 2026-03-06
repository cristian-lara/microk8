# Steps – PostgreSQL (CloudNativePG)

Each step is validated by the orchestrator; after each completed step: **commit** and **pull** per `workflow/RULES.md`.

| Step | Action | Success criteria | Files / commands |
|------|--------|-------------------|------------------|
| 1 | Ensure namespace `platform` exists | `kubectl get ns platform` shows Active | `microk8s kubectl create namespace platform` (if missing) |
| 2 | Apply PostgreSQL (CloudNativePG) | Cluster resource created; pods for `platform-db` reach Running | `chmod +x docs/k8s/postgres/apply-postgres-platform.sh && ./docs/k8s/postgres/apply-postgres-platform.sh` (from repo root) |
| 3 | Wait for DB ready | `platform-db-1` (or primary) pod Running, PVC bound | `microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db` |
| 4 | (Optional) Create Gitea DB | DB `gitea` exists if Gitea will be deployed | `GITEA_DB_PASSWORD='...' ./docs/k8s/postgres/create-gitea-db.sh` |
| 5 | (Optional) Create Vault DB user | User `vault` exists for Database Secrets Engine | `VAULT_DB_ADMIN_PASSWORD='...' ./docs/k8s/postgres/create-vault-db-user.sh` |
| 6 | Validation | Pods Running, PVCs bound with `nfs-storage` | `docs/k8s/scripts/validate-platform.sh` or `kubectl get pods,pvc -n platform` |

---

Reference: `docs/plan-de-trabajo.md` §5, `docs/k8s/vault/vault-postgres-integration.md` for order with Vault.
