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

Resumen de prioridades (detallado en `plan-de-trabajo.md`):

1. VM + MicroK8s + `nfs-storage`.
2. Cloudflare Tunnel + Access (piloto `test.cld-lf.com`).
3. Namespace `platform`.
4. Vault (secrets) usando PVC en `nfs-storage`.
5. PostgreSQL (CloudNativePG) para la plataforma.
6. Gitea (código) → usa PostgreSQL.
7. ArgoCD (GitOps) → se integra con Gitea.
8. CI/Registry (opcional).
9. Apps de negocio a través de ArgoCD, con secretos desde Vault y exposición por Tunnel + Access.

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

## 9. Workflow de análisis y ejecución

Para levantar o modificar servicios de forma ordenada y validada existe el directorio **`workflow/`** en la raíz del repo:

- **Análisis** (`workflow/analysis/`): dependencias, orden, riesgos y estándares antes de implementar.
- **Ejecución** (`workflow/execution/`): pasos validados; tras cada step completado se hace **pull** (y commit).
- **Orquestador** (`workflow/ORCHESTRATOR.md`): valida cada tarea y mantiene la tabla de aprendizaje en `workflow/LEARNING.md`.
- **Un directorio por servicio** en `workflow/services/<servicio>/` con pasos y criterios de éxito (plantilla en `_template/`).

**Skills** (`workflow/skills/`): el workflow puede desplegar **servicios de mercado** (PostgreSQL, Vault, Gitea, ArgoCD, Woodpecker, Harbor, etc.) y **servicios custom** (aplicaciones propias), con las mismas mejores prácticas. La **salida a internet es siempre HTTPS sin port forwarding** vía Cloudflare Tunnel + subdominio + (recomendado) Access; ver `workflow/skills/cloudflare-https-exposure.md` y `workflow/skills/service-catalog.md`.

Cualquier IA o persona que trabaje en despliegues debe leer `docs/plan-de-trabajo.md` y `docs/08-notas-implementacion.md` y, si usa el workflow, seguir los flujos de análisis y ejecución y la regla de pull post-step.

