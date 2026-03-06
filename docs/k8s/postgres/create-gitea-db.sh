#!/usr/bin/env bash
# Create Gitea database and user in platform-db. Run once after platform-db-1 is Running.
# Password: set GITEA_DB_PASSWORD env var (or pass as first arg). Do not commit passwords.
# Run from repo root: GITEA_DB_PASSWORD='secret' ./docs/k8s/postgres/create-gitea-db.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GITEA_PASS="${GITEA_DB_PASSWORD:-$1}"
if [ -z "$GITEA_PASS" ]; then
  echo "Set GITEA_DB_PASSWORD or pass password as first argument."
  exit 1
fi

POD=$(microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD" ]; then
  echo "No platform-db pod found. Deploy the cluster first."
  exit 1
fi

echo "Creating database and user gitea on $POD..."
# CREATE DATABASE no puede ejecutarse dentro de un bloque de transacción,
# por eso separamos en varias llamadas a psql.
microk8s kubectl exec -n platform "$POD" -c postgres -- \
  psql -U postgres -v ON_ERROR_STOP=1 -c "CREATE USER gitea WITH PASSWORD '$GITEA_PASS';"

microk8s kubectl exec -n platform "$POD" -c postgres -- \
  psql -U postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE gitea OWNER gitea;"

microk8s kubectl exec -n platform "$POD" -c postgres -- \
  psql -U postgres -v ON_ERROR_STOP=1 -c "GRANT ALL PRIVILEGES ON DATABASE gitea TO gitea;"

echo "Done. Use this connection from Gitea (if you ever need static creds):"
echo "  host=platform-db-rw.platform.svc.cluster.local port=5432 dbname=gitea user=gitea"
echo "For producción, preferir credenciales dinámicas de Vault (database/creds/gitea)."
