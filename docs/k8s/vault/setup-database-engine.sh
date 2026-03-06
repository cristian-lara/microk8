#!/usr/bin/env bash
# Enable Vault Database Secrets Engine and configure it for platform-db (PostgreSQL).
# Creates dynamic roles for apps (e.g. gitea). Run once after Vault is unsealed and vault DB user exists.
#
# Required env: VAULT_ADDR (e.g. http://127.0.0.1:8200 with port-forward), VAULT_TOKEN (root or admin),
#               VAULT_DB_ADMIN_PASSWORD (password of PostgreSQL user "vault").
# From repo root: VAULT_ADDR=... VAULT_TOKEN=... VAULT_DB_ADMIN_PASSWORD=... ./docs/k8s/vault/setup-database-engine.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ] || [ -z "$VAULT_DB_ADMIN_PASSWORD" ]; then
  echo "Set VAULT_ADDR, VAULT_TOKEN, VAULT_DB_ADMIN_PASSWORD."
  exit 1
fi

export VAULT_ADDR VAULT_TOKEN

# Enable database secrets engine at database/
vault secrets enable -path=database database 2>/dev/null || vault secrets enable -path=database database

# Connection URL. From host: port-forward postgres (5432) and set CONNECTION_URL="postgresql://vault:PASS@127.0.0.1:5432/postgres?sslmode=disable"
CONN_URL="${CONNECTION_URL:-postgresql://vault:${VAULT_DB_ADMIN_PASSWORD}@platform-db-rw.platform.svc.cluster.local:5432/postgres?sslmode=disable}"
vault write database/config/platform-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="gitea,argocd" \
  connection_url="$CONN_URL"

# Role: gitea - credentials for Gitea app (create user, grant on database gitea)
# Requires database gitea to exist and: GRANT CONNECT ON DATABASE gitea TO vault WITH GRANT OPTION; (and schema grants)
vault write database/roles/gitea \
  db_name=platform-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE gitea TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\"; GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\"; ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Role: argocd - placeholder; adjust creation_statements when argocd DB exists
vault write database/roles/argocd \
  db_name=platform-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT CONNECT ON DATABASE postgres TO \"{{name}}\"; GRANT USAGE ON SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "Done. Apps can read credentials from: vault read database/creds/gitea (or database/creds/argocd)."
echo "Use External Secrets Operator or Vault Agent to inject into pods; do not store these in manifests."