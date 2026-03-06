# Vault + PostgreSQL integration (platform-db)

Vault's **Database Secrets Engine** is used to generate short-lived credentials for PostgreSQL (platform-db). Applications (Gitea, ArgoCD, etc.) request credentials from Vault instead of using static secrets; Vault creates the DB user and can rotate/revoke it.

## Flow

1. **PostgreSQL** (CloudNativePG `platform-db`) runs in namespace `platform`.
2. A dedicated **`vault`** user in PostgreSQL has `CREATEROLE` so Vault can create/revoke dynamic users.
3. **Vault** has the Database Secrets Engine enabled at `database/`, configured with the connection to `platform-db-rw.platform.svc.cluster.local:5432`.
4. **Roles** in Vault (e.g. `gitea`, `argocd`) define `creation_statements` and TTL; when an app requests credentials, Vault creates a PostgreSQL user and returns username/password.
5. **Apps** use Vault Agent, External Secrets Operator, or direct API to read `database/creds/<role>` and connect to PostgreSQL.

## Order of operations

1. Deploy PostgreSQL (CloudNativePG) and wait for `platform-db-1` Running.
2. Create the `vault` user in PostgreSQL: `VAULT_DB_ADMIN_PASSWORD='...' ./docs/k8s/postgres/create-vault-db-user.sh`
3. (Optional) Create app databases (e.g. Gitea): `GITEA_DB_PASSWORD='...' ./docs/k8s/postgres/create-gitea-db.sh`
4. Grant Vault permission to create users in app databases. For Gitea, run once after the `gitea` DB exists: `./docs/k8s/postgres/grant-vault-to-gitea.sh` (or run the SQL in that script manually as postgres).
5. Deploy Vault, init, unseal.
6. Enable and configure the Database Secrets Engine: `VAULT_ADDR=... VAULT_TOKEN=... VAULT_DB_ADMIN_PASSWORD=... ./docs/k8s/vault/setup-database-engine.sh`
7. Applications consume credentials from `database/creds/gitea` (or `argocd`) via External Secrets, Vault Agent, or API.

## Security notes

- The `vault` PostgreSQL user password is used only to configure Vault; it is not stored in this repo. Pass it via env var or interactive prompt.
- Dynamic credentials have a limited TTL (e.g. 1h default, 24h max); apps must renew or request new creds before expiry.
- Rotate the `vault` admin password in PostgreSQL periodically and update the connection config in Vault.

## Files in this repo

| File | Purpose |
|------|--------|
| `docs/k8s/postgres/create-vault-db-user.sh` | Creates the `vault` user in PostgreSQL (run once; password from env). |
| `docs/k8s/postgres/grant-vault-to-gitea.sh` | Grants `vault` the rights on DB `gitea` so Vault can create dynamic users for Gitea (run once after gitea DB exists). |
| `docs/k8s/vault/setup-database-engine.sh` | Enables database engine, configures platform-db connection, creates roles gitea/argocd (requires VAULT_ADDR, VAULT_TOKEN, VAULT_DB_ADMIN_PASSWORD). |

## Manual steps (if not using scripts)

- **PostgreSQL:** Create user `vault` with `CREATEROLE` and a secure password; grant it access to databases that will have dynamic roles (e.g. `gitea`).
- **Vault:** Enable engine `database`, configure connection with plugin `postgresql-database-plugin`, connection_url using the `vault` user. Create a role with `creation_statements` that create a role `{{name}}` with password `{{password}}` and grant privileges on the target database/schema.
