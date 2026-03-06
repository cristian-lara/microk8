# Análisis de Gitea – Despliegue desde cero

Fecha: 2026-03-06

---

## Fase 0: Contexto inicial

### 0.1 Fuentes de verdad revisadas

- `docs/plan-de-trabajo.md` §5: Gitea pendiente de desplegar.
- `docs/08-notas-implementacion.md` §7: Orden de instalación (PostgreSQL → Vault → Vault+DB → Gitea).
- Intento anterior falló por usar subcharts internos (postgresql-ha, valkey-cluster) en lugar de `platform-db`.

### 0.2 Alcance

- **Servicio**: Gitea (servidor Git).
- **Objetivo**: Nuevo despliegue limpio usando:
  - Base de datos externa: `platform-db` (CloudNativePG en namespace `platform`).
  - Sin subchart de PostgreSQL-HA ni Valkey-Cluster (se deshabilitan).
  - Persistencia en `nfs-storage`.
  - Exposición HTTPS vía Cloudflare Tunnel.

### 0.3 Tipo de servicio

- **Market**: Helm chart oficial de Gitea (`gitea-charts/gitea`).
- El chart soporta deshabilitar subcharts y usar bases de datos externas.

### 0.4 ¿Se expone externamente?

- **Sí**: `https://gitea.cld-lf.com`.
- Requiere: Ingress + Public Hostname en Cloudflare Tunnel + Access app.

### 0.5 ¿Tiene webhooks/callbacks?

- **Sí**: Gitea expone webhooks para CI (Woodpecker, Jenkins, etc.) y OAuth callbacks.
- **Configuración crítica**:
  - `ROOT_URL` = `https://gitea.cld-lf.com` (nunca localhost).
  - `DOMAIN` = `gitea.cld-lf.com`.
  - Cualquier webhook URL generado por Gitea usará este dominio.

---

## Fase 1: Dependencias y orden

### 1.1 Dependencias

| Tipo | Recurso | Estado |
|------|---------|--------|
| Infra | MicroK8s | ✅ |
| Infra | Helm | ✅ |
| Infra | Ingress (ingress-nginx) | ✅ |
| Infra | StorageClass `nfs-storage` | ✅ |
| Service | Namespace `platform` | ✅ |
| Service | CloudNativePG operator | ✅ |
| Service | PostgreSQL `platform-db` | ✅ Running |
| Service | Vault | ✅ Running |
| Service | Vault database engine | ⚠️ Parcialmente (ver nota) |
| External | Cloudflare Tunnel | ✅ |
| External | DNS `gitea.cld-lf.com` | ❌ Pendiente |
| External | Access app para Gitea | ❌ Pendiente |

**Nota sobre Vault database engine**: El motor está habilitado pero la integración completa (credenciales dinámicas para Gitea) se hará como siguiente paso tras el despliegue básico.

### 1.2 Orden en el plan

- **Después de**: PostgreSQL (✅), Vault (✅), Vault+DB (parcial).
- **Antes de**: ArgoCD.

---

## Fase 1b: Requisitos de persistencia y secretos

### 1b.1 ¿Necesita base de datos?

- **Sí**: PostgreSQL.
- Base de datos: `gitea` en `platform-db`.
- Usuario: `gitea` (creado con `create-gitea-db.sh`).
- Conexión: `platform-db-rw.platform.svc.cluster.local:5432`.
- **Credenciales**: Inicialmente desde Kubernetes Secret; roadmap a Vault.

### 1b.2 ¿Necesita NFS (volumen persistente)?

- **Sí**: Gitea almacena repositorios, LFS, attachments, etc.
- StorageClass: `nfs-storage`.
- Tamaño inicial: `10Gi` (ajustable).
- PVC: `gitea` o similar.

### 1b.3 ¿Necesita Vault?

- **Fase 1 (este despliegue)**: Password en Secret estático (creado por el script `create-gitea-db.sh`).
- **Fase 2 (post-despliegue)**: Migrar a credenciales dinámicas desde Vault (`database/creds/gitea`).

---

## Fase 2: Requisitos de seguridad y estándares

### 2.1 Namespace

- `platform` (componente de plataforma, no app de negocio).

### 2.2 Secretos

- Password de DB en Secret de Kubernetes (temporal).
- Admin password: generado y guardado en Secret.
- **Prohibido**: Passwords en claro en `values.yaml`.

### 2.3 Estándares YAML

| Requisito | Cumplimiento |
|-----------|-------------|
| Imagen versionada | ✅ `gitea/gitea:1.22.x` (no latest) |
| Resources (requests/limits) | ✅ Definidos |
| Probes (liveness/readiness) | ✅ Chart los incluye |
| SecurityContext | ✅ runAsNonRoot, fsGroup |

### 2.4 Red y exposición

- Service: ClusterIP (interno).
- Ingress: `gitea.cld-lf.com` → Service `gitea-http:3000`.
- Cloudflare Tunnel: Public Hostname `gitea.cld-lf.com` → Ingress.
- Access: Protección con IdP (Google) + MFA.

### 2.5 URLs y webhooks (crítico)

- `ROOT_URL`: `https://gitea.cld-lf.com`
- `DOMAIN`: `gitea.cld-lf.com`
- `PROTOCOL`: `http` (termination TLS en Cloudflare/Ingress).
- **Nunca**: `localhost`, `127.0.0.1`, IP privada.

---

## Fase 3: Riesgos y excepciones

### 3.1 Riesgos

| Riesgo | Mitigación |
|--------|-----------|
| NFS ownership issues | Squash "No mapping" ya configurado |
| Vault sealed tras restart | Unseal manual (documentado en runbook) |
| Credenciales estáticas iniciales | Migrar a Vault en Fase 2 |
| DNS propagation | Crear registro antes de probar |

### 3.2 Excepciones

- **Credenciales estáticas**: Se acepta temporalmente para simplificar el despliegue inicial. La contraseña está en un Secret de Kubernetes, no en el values.yaml en texto plano. Se documentará migración a Vault.

---

## Fase 4: Entregables para ejecución

### 4.1 Archivos a crear/modificar

| Archivo | Acción |
|---------|--------|
| `docs/k8s/gitea/values-gitea-prod.yaml` | Reescribir desde cero |
| `docs/k8s/gitea/apply-gitea-platform.sh` | Actualizar |
| `docs/k8s/postgres/create-gitea-db.sh` | Ya existe, verificar |
| `workflow/services/gitea/README.md` | Crear |
| `workflow/services/gitea/analysis.md` | Este archivo |
| `workflow/services/gitea/steps.md` | Crear |

### 4.2 Configuración clave del values.yaml

```yaml
# Deshabilitar subcharts internos
postgresql-ha:
  enabled: false

valkey-cluster:
  enabled: false

# Base de datos externa
gitea:
  config:
    database:
      DB_TYPE: postgres
      HOST: platform-db-rw.platform.svc.cluster.local:5432
      NAME: gitea
      USER: gitea
      PASSWD: <desde Secret>
    server:
      ROOT_URL: https://gitea.cld-lf.com
      DOMAIN: gitea.cld-lf.com

# Persistencia
persistence:
  enabled: true
  storageClass: nfs-storage
  size: 10Gi

# Security
podSecurityContext:
  fsGroup: 1000
securityContext:
  runAsNonRoot: true
  runAsUser: 1000

# Resources
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 1
    memory: 1Gi
```

### 4.3 Pasos de ejecución

Ver `steps.md`.

### 4.4 Criterios de éxito

1. Pod `gitea-0` en `Running` con `1/1` containers ready.
2. PVC `gitea` en `Bound` con StorageClass `nfs-storage`.
3. Conexión a `platform-db` exitosa (sin errores en logs).
4. Acceso web a `https://gitea.cld-lf.com` (tras configurar DNS + Tunnel).
5. Auditor de producción aprobado.

---

## Decisiones de diseño

1. **Sin Redis/Valkey**: Para un despliegue single-node, Gitea funciona sin cache externa (usa cache en memoria). Si en el futuro se necesita HA o mejor rendimiento, se puede añadir Redis externo.

2. **Deshabilitar subcharts**: `postgresql-ha.enabled: false` y `valkey-cluster.enabled: false` evitan duplicar infra (ya tenemos `platform-db`).

3. **Password en Secret**: El chart de Gitea soporta `existingSecret` para el password de DB; usamos eso en lugar de poner el password en el values.yaml.

4. **Ingress separado**: El chart puede crear Ingress, pero lo configuraremos via values para cumplir con los estándares.
