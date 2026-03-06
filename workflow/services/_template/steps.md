# Steps – <SERVICIO>

Ordered execution steps. Each step is validated by the orchestrator; after each completed step, do **commit** and **pull** per `workflow/RULES.md`.

**Antes del commit del YAML:** generar resumen de configuraciones → presentar al usuario → iterar hasta aceptar → al aceptar: commit + comando de validación (ver `workflow/execution/flow-execution.md`).

| Step | Action | Success criteria | Files / commands |
|------|--------|-------------------|------------------|
| 0 | (If needed) Create YAML/manifests | Resumen generado; usuario acepta; luego commit | Create/edit files in `docs/k8s/<servicio>/` |
| 1 | Create namespace if needed | Namespace exists | `kubectl create namespace <NAMESPACE>` or script |
| 2 | … | … | … |
| 3 | Apply main manifests/Helm | Pods Running, no CrashLoopBackOff | `./docs/k8s/<servicio>/apply-*.sh` |
| 4 | (Optional) Configure Ingress | Ingress resource created, backend healthy | `./docs/k8s/<servicio>/apply-ingress-*.sh` |
| 5 | (If exposed) **Cloudflare HTTPS** (no port forwarding) | Public Hostname + DNS + Access; `https://<subdominio>.cld-lf.com` works | See `workflow/skills/cloudflare-https-exposure.md`: Tunnel Public Hostname, DNS, Access |
| 6 | **Validation** (comando para validar que el servicio corre) | Pods Running, PVCs bound (if any); if exposed, HTTPS OK | **Comando:** `microk8s kubectl get pods -n <NAMESPACE> -l <label>`; if exposed: open `https://<subdominio>.cld-lf.com` |

---

**Customize** this table for the service: add/remove steps, set exact script paths and success criteria. The **validation command** (step 5 or equivalent) must be the one given to the user after they accept the YAML, to verify the service is running correctly after apply.
