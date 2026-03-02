---
stepsCompleted: [1]
inputDocuments: []
session_topic: 'Levantar MicroK8s en Ubuntu Server sin port forwarding; cada app con su subdominio saliendo por 443'
session_goals: 'Tener claro el modelo: sin port forwarding, un subdominio por app, todo por 443 (Cloudflare Tunnel)'
selected_approach: ''
techniques_used: []
ideas_generated: []
context_file: 'docs/'
---

# Brainstorming Session Results

**Facilitator:** Cristian Lara
**Date:** 2026-03-01

### Contexto cargado (docs/)
- **00-resumen.md:** VM Ubuntu 24.04 en Synology VMM, MicroK8s single-node, Cloudflare Tunnel + Access (Google + MFA), apps en `*.cld-lf.com` (Vault, ArgoCD, Gitea, etc.).
- **02-microk8s-bootstrap.md:** Pasos de instalación (snap, grupo microk8s, `status --wait-ready`), addons base (dns, ingress, helm3, hostpath-storage), validación con kubectl.
- Orden recomendado en docs: VM → MicroK8s + addons → Tunnel → Access → migrar vault/argo.

## Session Overview

**Topic:** Levantar MicroK8s en Ubuntu Server sin port forwarding; cada app con su subdominio saliendo por 443.

**Goals:** Tener claro el modelo: sin port forwarding, un subdominio por app, todo por 443 (Cloudflare Tunnel).

### Context Guidance

Arquitectura ya documentada en docs: VM Ubuntu en Synology VMM, MicroK8s single-node, Cloudflare Tunnel (no port-forwarding), Cloudflare Access (Google + MFA). Apps en subdominios de cld-lf.com. El usuario quiere validar/refinar que el levantamiento sea sin abrir puertos y que cada app tenga subdominio propio saliendo por 443.

**Estado actual:** Hay port forwarding en el NAS hacia el servicio; en Cloudflare está la nubecita naranja (proxy) y el tráfico llega por 443. **Objetivo:** pasar a Cloudflare Tunnel (sin port forwarding en el NAS), manteniendo un subdominio por app y todo por 443.

### Session Setup

Foco confirmado: claridad sobre el modelo de publicación (sin port forwarding, subdominio por app, tráfico por 443).

