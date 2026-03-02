# 04 - Migrar `vault.cld-lf.com` con Tunnel + Access (paso a paso)

## Pre-requisitos
- Tunnel y Access funcionando con `test.cld-lf.com`.
- Vault desplegado internamente.

## 1) Public hostname
1. Tunnel -> `Public Hostnames` -> Add.
2. Hostname: `vault.cld-lf.com`.
3. Service: apunta al destino interno (ideal: Ingress).

## 2) Access App
1. Access -> Applications -> Add -> Self-hosted.
2. Domain: `vault.cld-lf.com`.
3. Allow policy:
   - `cristian89lara@gmail.com`
   - `cristian.lara@manticore-labs.com`
4. MFA: obligatorio.

## 3) Validación
- Abrir `https://vault.cld-lf.com`.
- Debe pedir login Google y luego cargar Vault.

## 4) DNS
- Mantener `cld-lf.com` (root) al NAS.
- Migrar `vault` a tunnel (CNAME) cuando ya funcione.
