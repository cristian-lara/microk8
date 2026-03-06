#!/usr/bin/env bash
# Create PostgreSQL user "vault" with CREATEROLE for Vault Database Secrets Engine.
# Vault will use this user to create/revoke dynamic DB users. Run once after platform-db is up.
# Password: set VAULT_DB_ADMIN_PASSWORD env var. Do not commit. Store in Vault or secret manager after use.
# Run from repo root: VAULT_DB_ADMIN_PASSWORD='...' chmod +x docs/k8s/postgres/create-vault-db-user.sh && ./docs/k8s/postgres/create-vault-db-user.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VAULT_PASS="${VAULT_DB_ADMIN_PASSWORD:-$1}"
if [ -z "$VAULT_PASS" ]; then
  echo "Set VAULT_DB_ADMIN_PASSWORD or pass as first argument."
  exit 1
fi

POD=$(microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD" ]; then
  echo "No platform-db pod found. Deploy the cluster first."
  exit 1
fi

echo "Creating user vault with CREATEROLE on $POD..."
microk8s kubectl exec -n platform "$POD" -c postgres -- psql -U postgres -v ON_ERROR_STOP=1 -c "
CREATE USER vault WITH CREATEROLE LOGIN PASSWORD '$VAULT_PASS';
-- Allow vault to grant connect on databases it can connect to (grant option on postgres for bootstrap).
GRANT CONNECT ON DATABASE postgres TO vault;
"
echo "Done. Use this password when configuring Vault Database Secrets Engine (setup-database-engine.sh)."
echo "After creating app databases (e.g. gitea), grant vault access: see docs/k8s/vault/vault-postgres-integration.md"