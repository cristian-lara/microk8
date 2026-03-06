# Steps: Gitea

Pasos ordenados para desplegar Gitea. Cada paso debe ser validado antes de continuar; tras cada step completado, hacer `git pull` desde la VM per `workflow/RULES.md`.

---

## Pre-requisitos (verificar antes de empezar)

- [ ] PostgreSQL `platform-db` Running en namespace `platform`.
- [ ] Base de datos `gitea` y usuario `gitea` creados (script `create-gitea-db.sh`).
- [ ] Vault Running (opcional para credenciales dinámicas en Fase 2).
- [ ] NFS Squash configurado como "No mapping" en Synology.

---

## Step 1: Verificar/crear base de datos Gitea

**Archivos**: `docs/k8s/postgres/create-gitea-db.sh`

**Comando** (en la VM):
```bash
cd ~/apps/microk8
git pull --rebase

# Verificar que platform-db está running
microk8s kubectl get pods -n platform -l cnpg.io/cluster=platform-db

# Crear DB y usuario si no existe
export GITEA_DB_PASSWORD='<password-seguro>'
chmod +x docs/k8s/postgres/create-gitea-db.sh
./docs/k8s/postgres/create-gitea-db.sh
```

**Criterio de éxito**: Script termina sin errores; `\l` en psql muestra DB `gitea`.

---

## Step 2: Crear Secrets (DB y Admin)

**Comando** (en la VM):
```bash
# Secret con el password de Gitea DB
microk8s kubectl create secret generic gitea-db-secret \
  --namespace platform \
  --from-literal=password='<mismo-password-de-step-1>' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -

# Secret con credenciales del admin de Gitea
microk8s kubectl create secret generic gitea-admin-secret \
  --namespace platform \
  --from-literal=username='gitea_admin' \
  --from-literal=password='<password-admin-seguro>' \
  --from-literal=email='admin@gitea.local' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

**Criterio de éxito**: 
```bash
microk8s kubectl get secret gitea-db-secret -n platform
microk8s kubectl get secret gitea-admin-secret -n platform
```
Ambos secrets existen.

---

## Step 3: Aplicar Gitea via Helm

**Archivos**: `docs/k8s/gitea/values-gitea-prod.yaml`, `docs/k8s/gitea/apply-gitea-platform.sh`

**Comando** (en la VM):
```bash
cd ~/apps/microk8
git pull --rebase

chmod +x docs/k8s/gitea/apply-gitea-platform.sh
./docs/k8s/gitea/apply-gitea-platform.sh
```

**Criterio de éxito**:
- Pod `gitea-0` en `Running` con `1/1`.
- PVC `gitea` en `Bound` con `nfs-storage`.
- Logs sin errores de conexión a DB.

**Verificación**:
```bash
microk8s kubectl get pods -n platform -l app.kubernetes.io/name=gitea
microk8s kubectl get pvc -n platform | grep gitea
microk8s kubectl logs -n platform gitea-0 | head -50
```

---

## Step 4: Configurar DNS y Cloudflare Tunnel

**Manual en Cloudflare Dashboard**:

1. **DNS**: Crear registro CNAME/Tunnel para `gitea.cld-lf.com` → túnel `home-microk8s`.
2. **Tunnel Public Hostname**: 
   - Hostname: `gitea.cld-lf.com`
   - Service: `http://gitea-http.platform.svc.cluster.local:3000`
3. **Access App** (recomendado):
   - Crear app en Zero Trust → Access → Applications.
   - Dominio: `gitea.cld-lf.com`.
   - Políticas: IdP Google + allowlist de emails + MFA.

**Criterio de éxito**: `https://gitea.cld-lf.com` muestra la UI de Gitea (o pantalla de login de Access).

---

## Step 5: Validación final

**Comandos**:
```bash
# Estado de pods
microk8s kubectl get pods -n platform | grep gitea

# Logs (verificar sin errores)
microk8s kubectl logs -n platform gitea-0 --tail=100

# Probar conectividad a DB desde el pod
microk8s kubectl exec -n platform gitea-0 -- gitea doctor check
```

**Criterio de éxito**:
- Pod stable en Running.
- Sin errores de DB en logs.
- UI accesible via `https://gitea.cld-lf.com`.

---

## Step 6: Crear usuario admin (primera vez)

Una vez accesible la UI:

1. Ir a `https://gitea.cld-lf.com/install` o `https://gitea.cld-lf.com/user/sign_up` (si sign_up está habilitado).
2. Si `INSTALL_LOCK: true`, el admin se crea via CLI:
   ```bash
   microk8s kubectl exec -n platform gitea-0 -- gitea admin user create \
     --username gitea_admin \
     --password '<password-seguro>' \
     --email admin@gitea.local \
     --admin
   ```

**Criterio de éxito**: Login exitoso como admin.

---

## Siguiente: Fase 2 (Vault integration)

Tras estabilizar el despliegue básico:
- Migrar password de DB a Vault (ExternalSecret).
- Configurar role `gitea` en `database/roles/gitea` de Vault.
- Actualizar values para usar credenciales dinámicas.

Ver `docs/k8s/vault/vault-postgres-integration.md`.
