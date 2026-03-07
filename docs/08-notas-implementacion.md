# 08 - Notas de implementación y “gotchas” (microk8s + Cloudflare + Synology)

Este archivo resume los problemas/inconvenientes que ya aparecieron al montar el entorno y las decisiones que tomamos, para poder **replicar la plataforma más rápido en otro lado**.

---

## 1. Red, VM y MicroK8s

- La VM debe estar en **bridge** en la LAN (`192.168.50.0/24`) con IP fija/reservada (ej. `192.168.50.237`).
- Verificación rápida:
  - `ip addr` → interfaz principal (ej. `enp3s0`) con IP en `192.168.50.x`.
  - SSH desde la LAN → `ssh microk8@192.168.50.237`.

---

## 2. NFS en Synology (para `nfs-storage`)

Problema típico: `showmount -e` no muestra exports.

- Solución:
  1. Activar NFS: Panel de control → File Services → pestaña **NFS** → *Enable NFS service*.
  2. Crear carpeta compartida `k8s` en `volume1`.
  3. En la carpeta `k8s` → **Edit → NFS Permissions**:
     - Hostname/IP: `192.168.50.0/24` o solo la IP de la VM.
     - Privilege: Read/Write.
     - Squash: **recomendado *No mapping*** para que los UID del cliente (p. ej. 26 para PostgreSQL) se conserven en el NAS. Si usas *Map all users to admin*, PostgreSQL (CloudNativePG) falla con "data directory has wrong ownership" (ver más abajo).
  4. En la VM:
     - `sudo apt install -y nfs-common`
     - `showmount -e 192.168.50.254` → debe aparecer `/volume1/k8s`.

Prueba de montaje:

```bash
sudo mkdir -p /mnt/nas-k8s
sudo mount -t nfs -o vers=3 192.168.50.254:/volume1/k8s /mnt/nas-k8s
touch /mnt/nas-k8s/_test_from_vm
ls -la /mnt/nas-k8s
sudo umount /mnt/nas-k8s
```

**PostgreSQL (CloudNativePG) y ownership en NFS:** Si al desplegar el cluster `platform-db` los pods de init fallan con *"FATAL: data directory ... has wrong ownership"*, es porque el squash NFS (p. ej. *Map all users to admin*) hace que los archivos en el NAS tengan el UID del admin (p. ej. 1024), mientras que el contenedor PostgreSQL corre como UID 26.

- **Solución recomendada:** En NFS Permissions del share `k8s`, cambiar Squash a **No mapping**. Así el UID 26 (y cualquier otro) se preserva y el directorio de datos queda con la ownership correcta. Luego, para que el operador recree todo desde cero: (1) borrar el Cluster (no solo el PVC/Job), ya que si queda en estado "unrecoverable" el apply no hace nada: `microk8s kubectl delete cluster platform-db -n platform`. (2) Aplicar de nuevo: `./docs/k8s/postgres/apply-postgres-platform.sh`. El operador creará un nuevo PVC y un nuevo Job de initdb.
- **Alternativa (mantener "Map all to admin"):** Usar en el Cluster el UID/GID del usuario admin del Synology (típicamente 1024:100): en `postgres-platform.yaml`, en `spec.podSecurityContext`, poner `runAsUser: 1024`, `runAsGroup: 100`, `fsGroup: 100`. Comprobar en el NAS el UID real del usuario admin si difiere. Ver `workflow/LEARNING.md` entrada "CloudNativePG / NFS".

---

## 3. StorageClass NFS en MicroK8s

- Deshabilitamos `hostpath-storage` porque **no es adecuado para producción**.
- Instalamos `nfs-subdir-external-provisioner` vía Helm (`microk8s helm3`) apuntando a `/volume1/k8s` en el NAS.
- Resultado esperado:
  - `kubectl get storageclass` → `nfs-storage (default)` con provisioner `nfs-nas-nfs-subdir-external-provisioner`.

Decisión: **toda la plataforma** (PostgreSQL, Vault, etc.) usa `nfs-storage` como StorageClass por defecto.

---

## 3b. Ingress: Helm en lugar del addon

- **No usar** el addon de MicroK8s (`microk8s enable ingress`) para el controlador Ingress. En pruebas puede sugerirse otro addon o comportamientos distintos; para homogeneidad y mejores prácticas se instala el controlador **vía Helm** (chart `ingress-nginx`).
- **Ventajas:** versionado claro, valores configurables (recursos, imagen fija), alineado con el resto de la plataforma (Helm). Evita depender del addon de MicroK8s y sus posibles cambios.
- **Pasos:** ver `docs/02-microk8s-bootstrap.md` sección "Ingress vía Helm". Namespace recomendado: `ingress-nginx`. Para Cloudflare Tunnel, el Public Hostname apunta al puerto donde escucha el controller (ej. NodePort 80 o el Service del controller).
- **Mejores prácticas:** imagen versionada (no `:latest`), `resources.requests`/`limits` en el controller, y revisar anotaciones si se usa cert-manager o TLS.

---

## 4. Cloudflare Tunnel + Access – problemas típicos

### 4.1. Túnel y servicio `cloudflared`

- Túnel único `home-microk8s`.
- En la VM:
  - `sudo cloudflared service install <TOKEN>`
  - `sudo systemctl status cloudflared` → debe estar `active (running)`.

### 4.2. Warning amarillo “No DNS record found for this domain”

- Aparece al crear la app de Access (`test.cld-lf-piloto`) con public hostname `test.cld-lf.com`.
- Es **esperado** mientras no exista el registro DNS.
- Se resuelve creando un registro `Tunnel`/`CNAME` para `test`:
  - En DNS de `cld-lf.com`:
    - Tipo: `Tunnel` (recomendado) o CNAME.
    - Nombre: `test`.
    - Contenido: túnel `home-microk8s` (o `<tunnel-id>.cfargotunnel.com` si se usa CNAME).

### 4.3. NXDOMAIN al abrir `https://test.cld-lf.com`

- Causa: no hay registro DNS.
- Solución: crear el registro `Tunnel`/CNAME como se describe arriba y esperar propagación.
- Resultado deseado: al abrir `https://test.cld-lf.com` se ve la pantalla de **Cloudflare Access**.

### 4.4. Rutas privadas vs públicas

- En Zero Trust, las *hostname routes* privadas muestran un popup de WARP (split tunnels).
- **No usar ese flujo** para apps web públicas; usar:
  - Tunnel + Access App + registro `Tunnel`/CNAME en DNS.

---

## 5. Reglas de YAML productivo

Las reglas completas están en `.cursor/rules/k8s-yaml-prod.mdc`. Puntos clave:

- Sin `:latest`, siempre imágenes versionadas.
- Siempre `resources` (requests/limits), probes y `securityContext` endurecido.
- Nada de `hostNetwork`/`privileged` salvo casos muy justificados.
- Secretos:
  - No se permiten credenciales en claro en `Secret` ni `ConfigMap`.
  - Integración obligatoria con Vault mediante recursos tipo `ExternalSecret`/`SecretStore`.
- Webhooks/URLs:
  - En producción no se usan `localhost` ni IPs privadas en callbacks/integraciones.
  - Siempre dominios reales (`*.cld-lf.com`) a través del Tunnel.

---

## 6. Decisiones sobre identidad y acceso

- Puerta de entrada única: **Cloudflare Access + Google** como IdP externo.
- Para cada app expuesta:
  - Subdominio propio (`vault.cld-lf.com`, `argo.cld-lf.com`, etc.).
  - Access App asociada al túnel `home-microk8s` + políticas (allowlist, MFA).
- SSO interno entre apps (Keycloak u otro IdP) pendiente de diseño; hoy se asume:
  - Control de “quién entra” vía Access.
  - Roles internos gestionados en cada app (Argo, Gitea, etc.) hasta que se implemente IdP común.

---

## 7. Orden de instalación de plataforma (prioridad por seguridad)

Resumen de prioridades (detallado en `plan-de-trabajo.md`). **Orden estricto** para evitar dependencias rotas:

1. VM + MicroK8s + DNS + **Helm** + **Ingress vía Helm** (ingress-nginx) + `nfs-storage`.
2. Cloudflare Tunnel + Access (piloto `test.cld-lf.com`).
3. Namespace `platform`.
4. **Operador CloudNativePG** (Helm en `cnpg-system`); ver §9.
5. **PostgreSQL** (CloudNativePG) usando `nfs-storage`; esperar pods Running.
6. **Vault** (secrets) usando PVC en `nfs-storage`; init y unseal.
7. **Vault vinculado a PostgreSQL** (motor database, credenciales dinámicas); ver `docs/k8s/vault/vault-postgres-integration.md`.
8. **Gitea** (código) → usa PostgreSQL; auth local inicial.
9. **Keycloak** (IdP centralizado) → usa PostgreSQL; ver §13.
10. **Integrar Gitea con Keycloak** (OIDC) → reconfigurar auth.
11. **ArgoCD** (GitOps) → con Keycloak desde el inicio.
12. **Vault integrado con Keycloak** (OIDC auth method).
13. CI/Registry (opcional, ya con SSO).
14. Apps de negocio en namespaces propios, con secretos desde Vault, SSO desde Keycloak, y exposición por Tunnel + Access.

**Vault + PostgreSQL (credenciales dinámicas):** Tras tener PostgreSQL y Vault desplegados, se configura el motor de secretos **database** en Vault para que genere credenciales de PostgreSQL con rotación (TTL). Las apps (Gitea, ArgoCD, etc.) consumen `database/creds/gitea` (o el rol que corresponda) en lugar de un usuario fijo. Ver `docs/k8s/vault/vault-postgres-integration.md` y scripts: `create-vault-db-user.sh`, `grant-vault-to-gitea.sh`, `setup-database-engine.sh`.

---

## 8. Namespace `platform` – propósito

Este namespace se crea para que **cualquiera que despliegue la plataforma desde cero** tenga claro dónde van los componentes base:

- Todo lo que es “plataforma” (no apps de negocio) vive en `platform`:
  - Vault (gestión de secretos).
  - PostgreSQL/CloudNativePG (bases de datos de plataforma).
  - Gitea (Git).
  - ArgoCD (GitOps).
  - CI (Woodpecker), Registry, etc.
- Ventajas:
  - Aislar permisos y políticas (por ejemplo `NetworkPolicy` y `RBAC`) de la plataforma del resto de namespaces.
  - Facilitar backups y restauraciones selectivas.
  - Hacer más fácil entender “qué es plataforma” vs “qué son apps de negocio”.

Regla general para quien implemente desde cero:

- **No desplegar aplicaciones de negocio en `platform`**; crear otros namespaces (`apps`, `n8n`, `prod-xxx`, etc.) y consumir la plataforma (Vault, PostgreSQL, etc.) desde ahí.

---

## 9. Operador CloudNativePG (antes de PostgreSQL)

Para que el manifest `postgres-platform.yaml` (Cluster CRD) funcione, el **operador CloudNativePG** debe estar instalado.

### Recomendado: instalar con Helm

Usar **Helm** evita conflictos con addons de MicroK8s, permite fijar versión del operador y es el mismo método para el resto de la plataforma (Vault, Gitea, ArgoCD suelen ir por Helm). En la VM, con MicroK8s ya con `helm3` habilitado:

```bash
microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts
microk8s helm3 repo update
microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
```

Verificación: `microk8s kubectl get pods -n cnpg-system` (pods del operador en Running).

Referencia: [CloudNativePG Helm chart](https://cloudnative-pg.github.io/charts).

### Alternativa: addon de MicroK8s

Si prefieres el addon:

1. Si aparece **"Addon cloudnative-pg was not found"**, habilitar primero: `microk8s enable community`
2. Luego: `microk8s enable cloudnative-pg`

**Problema conocido:** si CloudNativePG ya estaba instalado con Helm, el addon puede fallar con *"Apply failed with conflicts: conflicts with helm"*. En ese caso se recomienda **usar solo Helm** (no mezclar addon y Helm para el mismo operador).

**Problema conocido (Helm):** si Helm falla con *"ConfigMap cnpg-default-monitoring exists and cannot be imported: invalid ownership metadata"* (o faltan etiquetas `app.kubernetes.io/managed-by`, `meta.helm.sh/release-name`), es porque en `cnpg-system` quedaron recursos de una instalación anterior (addon o manual) sin metadatos de Helm. Para una **instalación limpia con Helm**: borrar el namespace y reinstalar: `microk8s kubectl delete namespace cnpg-system`, luego volver a ejecutar el script de instalación (o los comandos Helm de esta sección). No borrar `cnpg-system` si ya tienes clusters PostgreSQL (p. ej. `platform-db`) en producción y gestionados por ese operador. Ver `workflow/LEARNING.md`.

**Problema conocido (CRDs con otro namespace):** si Helm falla con *"CustomResourceDefinition ... exists and cannot be imported ... meta.helm.sh/release-namespace must equal cnpg-system: current value is platform"*, las CRDs del operador fueron instaladas por una release en otro namespace (p. ej. `platform`). Dos opciones en la VM:

- **Opción A – Instalación limpia** (no tienes clusters PostgreSQL que conservar): (1) Listar releases en ese namespace: `microk8s helm3 list -n platform`. (2) Desinstalar la release de CloudNativePG: `microk8s helm3 uninstall <release> -n platform`. (3) Borrar las CRDs: `microk8s kubectl get crd -o name | grep postgresql.cnpg.io | xargs microk8s kubectl delete`. (4) Re-ejecutar `./docs/k8s/postgres/install-cnpg-operator.sh`. Atención: borrar las CRDs elimina también todos los recursos de tipo Cluster, Backup, etc.; solo hacerlo si no necesitas conservarlos.
- **Opción B – Conservar clusters existentes:** instalar el operador **sin** crear las CRDs (ya existen): `microk8s helm3 repo add cnpg https://cloudnative-pg.github.io/charts && microk8s helm3 repo update && microk8s helm3 install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace --set crds.create=false`. Verificación: `microk8s kubectl get pods -n cnpg-system`.

### Orden

Instalar el operador (Helm o addon) **antes** de ejecutar `./docs/k8s/postgres/apply-postgres-platform.sh`.

### Pod platform-db-1-initdb-* en PodInitializing (diagnóstico)

Si el PVC `platform-db-1` está **Bound** pero el pod de init (ej. `platform-db-1-initdb-xxxxx`) se queda en **PodInitializing** varios minutos:

1. **Eventos y estado del pod:**  
   `microk8s kubectl describe pod -n platform -l cnpg.io/cluster=platform-db`  
   (o sustituir por el nombre exacto del pod). Revisar la sección *Events* y el estado de los init containers.

2. **Logs del init container:**  
   `microk8s kubectl logs -n platform <nombre-del-pod> -c bootstrap`  
   (si el init se llama distinto, ver el nombre en el `describe`). Ahí suele aparecer si falla permisos, NFS o `initdb`.

Causas habituales: **initdb en NFS** puede tardar varios minutos (5–10 min); permisos/ownership del volumen con `fsGroup`/NFS; o montaje NFS lento. Si en los logs aparece **"data directory has wrong ownership"**, es un problema de NFS squash (ver párrafo "PostgreSQL (CloudNativePG) y ownership en NFS" en §2): usar Squash **No mapping** o, en su defecto, `runAsUser`/`runAsGroup` del admin del Synology.
---

## 10. Redeploy, persistencia de datos y arranque tras apagado

Para que **no se pierdan datos**, que el **redeploy** (volver a ejecutar apply/Helm) sea seguro y que tras **apagar** la VM o el cluster todo **levante normalmente**, se cumple lo siguiente.

### Persistencia (datos en NFS)

- **Toda la plataforma con estado** usa **PVCs** con StorageClass **`nfs-storage`** (NFS en Synology). Los datos quedan en el NAS, no en el disco de la VM.
- **PostgreSQL** (CloudNativePG): datos del cluster en PVC; el nombre del PVC es estable (p. ej. vinculado al nombre del Cluster). Al hacer redeploy del manifest o del operador, **no se borran** los PVCs existentes salvo que se eliminen a mano.
- **Vault**: storage en PVC (`nfs-storage`); datos de Vault (incl. sealed state) en el NAS.
- **Gitea** (y similares): repos y datos en PVCs con `nfs-storage`.

**Regla:** No eliminar namespaces con PVCs ni borrar PVCs a mano si se quiere conservar datos. Los scripts de apply (`apply-postgres-platform.sh`, `apply-vault-platform.sh`, etc.) hacen `kubectl apply` / `helm upgrade`; **no** eliminan PVCs.

### Redeploy seguro

- **Re-ejecutar** los scripts de apply (p. ej. `./docs/k8s/postgres/apply-postgres-platform.sh`, `./docs/k8s/vault/apply-vault-platform.sh`) o `helm upgrade` es **seguro**: actualiza manifiestos o releases sin borrar los PVCs. Los pods pueden reiniciarse y volver a montar los mismos volúmenes; los datos siguen en NFS.
- **Importante:** No usar `helm uninstall` ni `kubectl delete` sobre los recursos que tienen PVCs con datos que quieras conservar. Para “redeploy” se usa **apply** o **upgrade**, no uninstall + install.

### Arranque tras apagado (VM o cluster parado)

1. **VM / nodo:** Arrancar la VM (o el NAS si afecta al NFS). Si el servicio NFS está en el NAS, el NAS debe estar encendido antes o al mismo tiempo que la VM para que los montajes NFS respondan.
2. **MicroK8s:** `microk8s status --wait-ready` (o dejar que arranque solo). Los pods irán pasando a Running.
3. **PVCs:** Siguen en Bound; los pods que usan `nfs-storage` vuelven a montar los mismos volúmenes; **no se pierden datos**.
4. **PostgreSQL:** CloudNativePG arranca y usa los PVCs existentes; la base de datos se levanta con los datos intactos.
5. **Vault:** Los datos están en el PVC, pero tras un reinicio Vault suele quedar **sealed**. Hay que **unseal** manualmente (o con auto-unseal si está configurado). Sin unseal, las apps que dependen de Vault no podrán leer secretos hasta que se haga unseal.
6. **Gitea y resto:** Arrancan y montan sus PVCs; datos intactos.

**Resumen:** Los datos persisten en NFS. Redeploy con apply/upgrade es seguro. Tras apagar, todo levanta normal salvo **Vault**, que puede requerir **unseal** después del reinicio (documentar en runbook si se usa unseal manual).

### Checklist rápido

- [ ] StorageClass por defecto es `nfs-storage` (datos en NAS).
- [ ] No eliminar PVCs ni namespaces con datos sin backup.
- [ ] Redeploy = apply/helm upgrade, no uninstall.
- [ ] Tras reboot: comprobar pods Running; si usas Vault, ejecutar unseal si está sealed.

---

## 11. Workflow de análisis y ejecución

Para levantar o modificar servicios de forma ordenada y validada existe el directorio **`workflow/`** en la raíz del repo:

- **Análisis** (`workflow/analysis/`): dependencias, orden, riesgos y estándares antes de implementar.
- **Ejecución** (`workflow/execution/`): pasos validados; tras cada step completado se hace **pull** (y commit).
- **Orquestador** (`workflow/ORCHESTRATOR.md`): valida cada tarea y mantiene la tabla de aprendizaje en `workflow/LEARNING.md`.
- **Un directorio por servicio** en `workflow/services/<servicio>/` con pasos y criterios de éxito (plantilla en `_template/`).

**Skills** (`workflow/skills/`): el workflow puede desplegar **servicios de mercado** (PostgreSQL, Vault, Gitea, ArgoCD, Woodpecker, Harbor, etc.) y **servicios custom** (aplicaciones propias), con las mismas mejores prácticas. La **salida a internet es siempre HTTPS sin port forwarding** vía Cloudflare Tunnel + subdominio + (recomendado) Access; ver `workflow/skills/cloudflare-https-exposure.md` y `workflow/skills/service-catalog.md`.

Cualquier IA o persona que trabaje en despliegues debe leer `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md` y, si usa el workflow, seguir los flujos de análisis y ejecución y la regla de pull post-step.

---

## 12. Gitea – configuración y troubleshooting

### Configuración del Helm chart

El chart oficial de Gitea (`gitea-charts/gitea`) despliega por defecto subcharts de **PostgreSQL-HA** y **Valkey-Cluster**. Para usar nuestra infraestructura existente (`platform-db`), se deshabilitan en `values-gitea-prod.yaml`:

```yaml
postgresql-ha:
  enabled: false
valkey-cluster:
  enabled: false
redis-cluster:
  enabled: false
```

La base de datos se configura como externa apuntando a `platform-db-rw.platform.svc.cluster.local:5432`, con el password cargado desde un Secret de Kubernetes (`gitea-db-secret`) via `additionalConfigFromEnvs`.

### Cloudflare Tunnel – URL correcta

El túnel (`cloudflared`) corre como servicio de sistema en la VM, **fuera del cluster**. Por esto, **no puede resolver DNS internos de Kubernetes** como `gitea-http.platform.svc.cluster.local`.

**Configuración correcta del Public Hostname**:
- Type: `HTTP`
- URL: `localhost:80`

El flujo es: Cloudflare → Tunnel → localhost:80 (Ingress controller MicroK8s) → Ingress `gitea.cld-lf.com` → Service `gitea-http` → Pod Gitea.

### Gotcha: password de usuario existente

Si el usuario de DB (`gitea`) ya existía de un intento anterior con otro password, el pod falla con `password authentication failed`. Solución:

```bash
microk8s kubectl exec -n platform platform-db-1 -c postgres -- \
  psql -U postgres -c "ALTER USER gitea WITH PASSWORD '<password-correcto>';"
```

---

## 13. Identity Provider centralizado (Keycloak)

### Decisión arquitectónica

En lugar de gestionar usuarios locales en cada aplicación (Gitea, ArgoCD, Vault, etc.), se utiliza **Keycloak** como Identity Provider (IdP) centralizado. Esto permite:

- **Un solo lugar** para gestionar usuarios, roles y permisos.
- **SSO (Single Sign-On)**: Login una vez, acceso a todas las apps.
- **OIDC/OAuth2**: Protocolo estándar soportado por todas las apps de la plataforma.
- **Integración con Google**: Keycloak puede federar con Google como IdP externo.

### Arquitectura de autenticación

```
┌─────────────────────────────────────────────────────┐
│               Cloudflare Access                      │
│         (Primera capa - quién puede llegar)          │
└─────────────────────┬───────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────┐
│                   Keycloak                           │
│     keycloak.cld-lf.com (IdP centralizado)          │
│     - Realm: cld-lf                                  │
│     - Usuarios, roles, grupos                        │
│     - Clients: gitea, argocd, vault, etc.           │
└─────────────────────┬───────────────────────────────┘
                      │ OIDC
        ┌─────────────┼─────────────┬─────────────┐
        ▼             ▼             ▼             ▼
    ┌───────┐    ┌────────┐    ┌───────┐    ┌────────┐
    │ Gitea │    │ ArgoCD │    │ Vault │    │ Harbor │
    └───────┘    └────────┘    └───────┘    └────────┘
```

### Orden de despliegue

1. **Keycloak** desplegado con PostgreSQL (`platform-db`).
2. Configurar realm `cld-lf`, crear usuarios admin, configurar IdP Google (opcional).
3. **Crear client OIDC** para cada app en Keycloak.
4. **Reconfigurar apps** (Gitea, ArgoCD, Vault) para usar Keycloak como auth provider.

### Roles sugeridos

| Rol | Descripción | Apps |
|-----|-------------|------|
| `admin` | Administrador de plataforma | Todas |
| `developer` | Desarrollador (push/pull code, deploy) | Gitea, ArgoCD |
| `viewer` | Solo lectura | Gitea (read), ArgoCD (view) |

### Bases de datos en platform-db

| App | Database | Usuario |
|-----|----------|---------|
| Gitea | `gitea` | `gitea` |
| Keycloak | `keycloak` | `keycloak` |
| ArgoCD | (usa ConfigMaps/Secrets) | N/A |
| Harbor | `harbor` | `harbor` |

