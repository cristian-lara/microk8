# Checklist de producción (auditor)

El auditor comprueba cada ítem. Cualquier fallo debe corregirse y re-auditar antes de presentar al usuario. **Ser estrictos y críticos.**

## 1. Imagen y despliegue

- [ ] **No** hay tag `:latest`; la imagen está versionada (ej. `app:v1.2.3`).
- [ ] Si aplica: `replicas` ≥ 2 para workloads críticos; `revisionHistoryLimit` definido (3–5).

## 2. Recursos

- [ ] Todos los contenedores tienen `resources.requests.cpu`, `resources.requests.memory`, `resources.limits.cpu`, `resources.limits.memory`.

## 3. Seguridad de pods

- [ ] Existe `securityContext` (pod y/o contenedor): `runAsNonRoot`, `allowPrivilegeEscalation: false`, `privileged: false`, `capabilities.drop: ["ALL"]` (añadir solo las necesarias).
- [ ] No hay `hostNetwork`, `hostPID`, `hostIPC` ni `hostPath` salvo excepción documentada.

## 4. Salud

- [ ] Hay `livenessProbe` y `readinessProbe` (y `startupProbe` si el servicio tarda en arrancar).

## 5. Secretos

- [ ] **No** hay contraseñas, tokens ni API keys en claro en `Secret.data`, `Secret.stringData`, `ConfigMap` ni en `values.yaml` de producción.
- [ ] Los secretos vienen de Vault (ExternalSecret/SecretStore) o está documentado el flujo seguro.

## 6. Webhooks y URLs públicas (crítico)

- [ ] Se ha **investigado** si la aplicación tiene webhooks, callbacks o URLs que deban ser accesibles desde fuera (Git, CI, OAuth, notificaciones, etc.).
- [ ] **Ninguna** variable de entorno ni opción de configuración que defina URL pública, webhook o callback contiene:
  - `localhost`, `127.0.0.1`
  - IP privada (192.168.x.x, 10.x.x.x) como host de URL pública
  - Nombre de servicio interno (ej. `http://gitea.platform.svc:3000`) como URL que deba usar un cliente externo
- [ ] Las URLs públicas, webhooks y callbacks usan **dominio real**: `https://<subdominio>.cld-lf.com` (dominio base **cld-lf.com**, subdominio definido para el servicio).
- [ ] Ejemplos correctos: `ROOT_URL=https://gitea.cld-lf.com`, `WEBHOOK_URL=https://n8n.cld-lf.com/webhook`, etc.

**Si la app tiene webhooks/callbacks y alguna variable sigue en localhost/127.0.0.1 → FALLO; no aprobar hasta corregir.**

## 7. Red y exposición

- [ ] **Servicios de la aplicación**: tipo ClusterIP. (El controller de Ingress puede usar NodePort para 80/443; es la excepción documentada.)
- [ ] Si se expone: Ingress con host = subdominio (ej. `gitea.cld-lf.com`); exposición vía Cloudflare Tunnel (no port forwarding).

## 8. Namespace

- [ ] Namespace correcto: `platform` solo para componentes de plataforma; apps de negocio en otro namespace.

## 9. Helm values – Validación Estricta (si aplica)

### 9.1 Preparación (ANTES de crear el values)
- [ ] Se ejecutó `helm show values <chart>` para conocer los valores por defecto.
- [ ] Se leyó la documentación oficial del chart (README, ArtifactHub).
- [ ] Se identificaron TODOS los parámetros requeridos para producción.

### 9.2 Contenido del values.yaml
- [ ] `image.tag` específico (nunca `:latest`).
- [ ] `resources.requests` y `resources.limits` definidos y realistas.
- [ ] `securityContext` de producción (`runAsNonRoot`, `allowPrivilegeEscalation: false`).
- [ ] `livenessProbe` y `readinessProbe` configurados.
- [ ] `storageClass: nfs-storage` si hay persistencia.
- [ ] Sin credenciales en claro; referencia a Vault/ExternalSecret.
- [ ] URLs/callbacks con dominio real (`*.cld-lf.com`), nunca localhost.

### 9.3 Validación técnica (OBLIGATORIA antes de aplicar)
- [ ] `helm lint <chart> -f values.yaml` → sin errores.
- [ ] `helm template <release> <chart> -f values.yaml --debug` → se revisó el YAML renderizado.
- [ ] `helm install ... --dry-run --debug` → sin errores de validación.
- [ ] En el YAML renderizado: namespace, labels, selectors, PVCs y Services son correctos.

**Si cualquier validación falla → NO aprobar. Corregir y re-validar.**

### 9.4 Protocolo ante errores (CRÍTICO)
- [ ] Si hubo error en deploy anterior: se ejecutó el **protocolo de error completo** (ver `.cursor/rules/helm-values-strict.mdc`).
- [ ] Se capturaron logs y eventos antes de modificar valores.
- [ ] Se identificó la **causa raíz** (no se cambió "a ver si funciona").
- [ ] Se re-ejecutó validación completa (Fases 1-4) tras cada corrección.

**Prohibido:** Aprobar si se detecta que se iteró sin análisis (prueba-error ciego).

---

## Resultado del auditor

- **Pasa**: todos los ítems aplicables marcados OK → se puede presentar el resumen al usuario.
- **Falla**: listar ítem(es) fallidos, archivo y (si aplica) clave/variable; el ejecutor corrige y se re-ejecuta el auditor hasta que pase.
