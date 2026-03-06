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

## 9. Helm values (si aplica)

- [ ] `values.yaml` sin `:latest`, con recursos y probes; sin credenciales en claro; sin URLs de prueba (localhost) en valores de producción.

---

## Resultado del auditor

- **Pasa**: todos los ítems aplicables marcados OK → se puede presentar el resumen al usuario.
- **Falla**: listar ítem(es) fallidos, archivo y (si aplica) clave/variable; el ejecutor corrige y se re-ejecuta el auditor hasta que pase.
