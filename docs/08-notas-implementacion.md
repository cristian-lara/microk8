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
     - Squash: *Map all users to admin*.
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
8. Gitea (código) → usa PostgreSQL y puede usar credenciales dinámicas de Vault.
9. ArgoCD (GitOps) → se integra con Gitea.
10. CI/Registry (opcional).
11. Apps de negocio en namespaces propios, con secretos desde Vault y exposición por Tunnel + Access.

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

### Orden

Instalar el operador (Helm o addon) **antes** de ejecutar `./docs/k8s/postgres/apply-postgres-platform.sh`.

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

