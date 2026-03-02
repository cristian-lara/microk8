# 03 - Cloudflare Tunnel + Cloudflare Access (Google + MFA) (paso a paso)

## Objetivo
Publicar `test.cld-lf.com` (piloto) y luego `vault.cld-lf.com` usando Cloudflare Tunnel y proteger con Cloudflare Access (Google + MFA).

## A) Crear Tunnel
1. Cloudflare Zero Trust -> `Networks` -> `Tunnels` -> `Create a tunnel`.
2. Tipo: `Cloudflared`.
3. Nombre: `home-microk8s`.
4. Copiar el comando con token.

## B) Instalar cloudflared en la VM
1. Instalar `cloudflared` según instrucciones oficiales.
2. `sudo cloudflared service install <TOKEN>`
3. `sudo systemctl status cloudflared`

## C) Public hostname piloto: `test.cld-lf.com`
1. En el tunnel -> `Public Hostnames` -> `Add a public hostname`.
2. Hostname: `test.cld-lf.com`.
3. Service (piloto): apunta a un destino interno válido.

## D) Access App para el piloto
1. Zero Trust -> `Access` -> `Applications` -> `Add an application` -> `Self-hosted`.
2. Domain: `test.cld-lf.com`.
3. IdP: Google.
4. Allow policy (emails):
   - `cristian89lara@gmail.com`
   - `cristian.lara@manticore-labs.com`
5. MFA: habilitar/forzar.

## E) Checklist
- Abrir `https://test.cld-lf.com`.
- Debe pedir login Google.
