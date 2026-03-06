#!/usr/bin/env bash
# Grant PostgreSQL user "vault" the rights needed to create dynamic users for Gitea.
# Run once after the gitea database exists (create-gitea-db.sh). No secrets in repo.
# From repo root: chmod +x docs/k8s/postgres/grant-vault-to-gitea.sh && ./docs/k8s/postgres/grant-vault-to-gitea.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

POD=$(microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD" ]; then
  echo "No platform-db pod found."
  exit 1
fi

echo "Granting vault user rights on database gitea (run as postgres) on $POD..."
microk8s kubectl exec -n platform "$POD" -c postgres -- psql -U postgres -v ON_ERROR_STOP=1 -d gitea -c "
GRANT CONNECT ON DATABASE gitea TO vault WITH GRANT OPTION;
GRANT USAGE ON SCHEMA public TO vault;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO vault WITH GRANT OPTION;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO vault WITH GRANT OPTION;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vault;
"
echo "Done. Vault can now create dynamic credentials for Gitea (role database/creds/gitea)."
