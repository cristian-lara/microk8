# Steps: Keycloak

Pasos ordenados para desplegar Keycloak como IdP centralizado.

---

## Pre-requisitos

- [ ] PostgreSQL `platform-db` Running en namespace `platform`.
- [ ] Vault Running (para guardar admin password en el futuro).
- [ ] NFS Squash configurado como "No mapping" en Synology.

---

## Step 1: Crear base de datos Keycloak

**Comando** (en la VM):
```bash
cd ~/apps/microk8
git pull --rebase

# Crear DB y usuario keycloak
export KEYCLOAK_DB_PASSWORD='<password-seguro>'

microk8s kubectl exec -n platform platform-db-1 -c postgres -- \
  psql -U postgres -c "CREATE USER keycloak WITH PASSWORD '$KEYCLOAK_DB_PASSWORD';"

microk8s kubectl exec -n platform platform-db-1 -c postgres -- \
  psql -U postgres -c "CREATE DATABASE keycloak OWNER keycloak;"

microk8s kubectl exec -n platform platform-db-1 -c postgres -- \
  psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;"
```

**Criterio de éxito**: `\l` en psql muestra DB `keycloak`.

---

## Step 2: Crear Secrets

**Comando** (en la VM):
```bash
# Secret con password de DB
microk8s kubectl create secret generic keycloak-db-secret \
  --namespace platform \
  --from-literal=password='<mismo-password-step-1>' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -

# Secret con password del admin de Keycloak
microk8s kubectl create secret generic keycloak-admin-secret \
  --namespace platform \
  --from-literal=admin-password='<password-admin-seguro>' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

**Criterio de éxito**: Ambos secrets existen en namespace `platform`.

---

## Step 3: Aplicar Keycloak via Helm

**Archivos**: `docs/k8s/keycloak/values-keycloak-prod.yaml`, `docs/k8s/keycloak/apply-keycloak-platform.sh`

**Comando** (en la VM):
```bash
cd ~/apps/microk8
git pull --rebase

chmod +x docs/k8s/keycloak/apply-keycloak-platform.sh
./docs/k8s/keycloak/apply-keycloak-platform.sh
```

**Criterio de éxito**:
- Pod `keycloak-0` en `Running` con `1/1`.
- Logs sin errores de conexión a DB.

---

## Step 4: Configurar Cloudflare Tunnel

**Manual en Cloudflare Dashboard**:

1. **Tunnel Public Hostname**: 
   - Subdomain: `keycloak`
   - Domain: `cld-lf.com`
   - Type: `HTTP`
   - URL: `localhost:80`

2. **Access App** (OBLIGATORIO para Keycloak):
   - Crear app en Zero Trust → Access → Applications.
   - Dominio: `keycloak.cld-lf.com`
   - Políticas: IdP Google + allowlist estricta + **MFA obligatorio**.

**Criterio de éxito**: `https://keycloak.cld-lf.com` muestra login de Keycloak.

---

## Step 5: Configurar Keycloak (post-deploy)

Acceder a `https://keycloak.cld-lf.com` con admin credentials.

### 5.1 Crear Realm
- Nombre: `cld-lf`
- Enabled: true

### 5.2 (Opcional) Configurar Google como Identity Provider
- Realm → Identity Providers → Add → Google
- Client ID y Secret de Google Cloud Console

### 5.3 Crear Clients OIDC

| Client ID | Root URL | Redirect URIs |
|-----------|----------|---------------|
| `gitea` | `https://gitea.cld-lf.com` | `https://gitea.cld-lf.com/*` |
| `argocd` | `https://argo.cld-lf.com` | `https://argo.cld-lf.com/auth/callback` |
| `vault` | `https://vault.cld-lf.com` | `https://vault.cld-lf.com/ui/vault/auth/oidc/oidc/callback` |

### 5.4 Crear Roles
- Realm Roles: `admin`, `developer`, `viewer`

### 5.5 Crear Usuario Admin
- Username: tu email o username preferido
- Asignar rol: `admin`

---

## Step 6: Integrar Gitea con Keycloak

Ver `workflow/services/gitea/steps.md` - sección de integración OIDC.

**Resumen**:
1. En Keycloak: copiar Client ID y Secret del client `gitea`.
2. En `values-gitea-prod.yaml`: añadir configuración OIDC.
3. Redeploy Gitea.

---

## Siguiente: ArgoCD con Keycloak

Continuar con `workflow/services/argocd/steps.md`, configurando OIDC desde el inicio.
