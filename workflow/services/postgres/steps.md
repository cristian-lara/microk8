# Steps – PostgreSQL (CloudNativePG)

Each step is validated by the orchestrator; after each completed step: **commit** and **pull** per `workflow/RULES.md`.

| Step | Action | Success criteria | Files / commands |
|------|--------|-------------------|------------------|
| 1 | Ensure namespace `platform` exists | `kubectl get ns platform` shows Active | `microk8s kubectl create namespace platform` (if missing) |
| 2 | Install CloudNativePG operator | Operator pods running in `cnpg-system` | **Helm (recommended):** `microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts && microk8s helm3 repo update && microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace`. Verify: `microk8s kubectl get pods -n cnpg-system`. Alternative: addon (see `docs/08-notas-implementacion.md` §9). |
| 3 | Apply PostgreSQL (CloudNativePG) | Cluster resource created; pods for `platform-db` reach Running | `chmod +x docs/k8s/postgres/apply-postgres-platform.sh && ./docs/k8s/postgres/apply-postgres-platform.sh` (from repo root) |
| 4 | Wait for DB ready | `platform-db-1` (or primary) pod Running, PVC bound | `microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db` |
| 5 | (Optional) Create Gitea DB | DB `gitea` exists if Gitea will be deployed | `GITEA_DB_PASSWORD='...' ./docs/k8s/postgres/create-gitea-db.sh` |
| 6 | (Optional) Create Vault DB user | User `vault` exists for Database Secrets Engine | `VAULT_DB_ADMIN_PASSWORD='...' ./docs/k8s/postgres/create-vault-db-user.sh` |
| 7 | Validation | Pods Running, PVCs bound with `nfs-storage` | `docs/k8s/scripts/validate-platform.sh` or `kubectl get pods,pvc -n platform` |

---

Reference: `docs/plan-de-trabajo.md` §5, `docs/k8s/vault/vault-postgres-integration.md` for order with Vault.
