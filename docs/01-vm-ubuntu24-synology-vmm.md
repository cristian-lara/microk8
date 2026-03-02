# 01 - Crear VM Ubuntu 24.04 en Synology VMM (paso a paso)

## Objetivo
- VM en Synology VMM conectada a la LAN `192.168.50.0/24`.
- IP estable via **reserva DHCP** en el router.

## Recomendación de recursos
- CPU: 6 vCPU (mínimo 4)
- RAM: 24 GB (mínimo 16 GB)
- Disco: 300 GB SSD (mínimo 200 GB)
- NIC: 1

## En la pantalla "Configure General Specifications" (tu captura)
- **Name**: `microk8s`
- **CPU(s)**: `6`
  - Si luego harás builds pesados/CI, puedes subir a 8.
- **Memory**: `24-32 GB` (tu `28 GB` está perfecto)
- **Video Card**: dejar el valor por defecto / mínimo
  - Esta VM será principalmente por SSH (headless), no necesita GPU/video.
- **Machine type**: `PC`
- **Virtual machine priority**: `Normal`
  - Si notas que la VM se queda sin CPU en horas pico, puedes subir a High, pero empieza en Normal.

## En Synology VMM
1. Crear VM.
2. Nombre sugerido: `microk8s`.
3. CPU/Memoria/Disco según sizing.
4. Disco:
   - Controlador recomendado: VirtIO/SCSI si está disponible.
5. Red:
   - Conectar a `Default VM Network` (External) o la red LAN equivalente.
   - La VM debe quedar en **bridge**.
6. Montar ISO Ubuntu Server 24.04.
7. Habilitar arranque y completar instalación.

## ¿Qué ISO usar? (Desktop vs Server)
- Recomendado: **Ubuntu Server** (`ubuntu-24.04.x-live-server-amd64.iso`).
  - Es más liviano, consume menos RAM/CPU, y es ideal para administrar por **SSH**.
  - Para MicroK8s/servicios (Vault, ArgoCD, etc.) no necesitas entorno gráfico.
- Usar **Ubuntu Desktop** sólo si realmente necesitas GUI dentro de la VM (normalmente no).

## En la pantalla "Configure Network" (tu captura)
- **Network**: seleccionar **`Default VM Network`**.
  - Debe ser la red **External** que sale por tu LAN (ej. LAN 1), para que la VM quede en `192.168.50.0/24`.
- **Cantidad de NICs**: dejar **1** (no agregar más al inicio).
- Evitar al inicio:
  - Redes tipo **Private/Internal/NAT** (complican acceso y reservas DHCP).
  - VLANs (si no las estás usando explícitamente).

## Advanced Options (recomendado para Ubuntu/MicroK8s)
Si ves opciones como las de tu captura:

- **Enable CPU compatibility mode**: dejar **desactivado**.
  - Sólo activarlo si estás en un cluster con más de 1 host y planeas **live migration** entre CPUs diferentes.
- **Enable Hyper-V Enlightenments**: dejar **desactivado**.
  - Está orientado a VMs **Windows**; para Ubuntu no aporta y puede confundir.
- **Reserved CPU Threads**: dejar en **0**.
  - Reservar CPU garantiza rendimiento de la VM, pero puede afectar a DSM.
  - Si más adelante la VM se queda “sin CPU” en builds de CI, podemos evaluar reservar 1-2 threads, pero no es necesario para empezar.

## En la pantalla "Other Settings" (Synology VMM)
- **ISO file for bootup**: Selecciona el ISO Ubuntu Server (`ubuntu-24.04.x-live-server-amd64.iso`).
- **Additional ISO file**: `Unmounted` (dejar así, salvo que instales drivers adicionales).
- **Autostart**: `No` (puedes dejarlo en No; si quieres que la VM arranque sola tras reboot del NAS, pon Yes).
- **Firmware**: `Legacy BIOS (Recommended)` (dejar por defecto, salvo que necesites UEFI para algo específico).
- **Keyboard Layout**: `Default (en-us)` (cámbialo solo si tu teclado es otro layout y vas a usar consola VMM mucho).
- **Serial port**: `Enable` (útil para debug vía consola, pero puedes dejarlo en Disable si nunca lo usas).
- **Virtual USB Controller**: `Disabled` (no lo necesitas para Ubuntu Server/MicroK8s; habilítalo solo si vas a montar USBs en la VM).

## Instalación Ubuntu
1. Seleccionar instalación server.
2. Habilitar OpenSSH server.
3. Usuario normal.
4. Al terminar:
   - `sudo apt update && sudo apt -y upgrade`

## Fijar IP: reserva DHCP en el router ASUS
1. Arrancar la VM y ver qué IP obtuvo (ej. `192.168.50.120`).
2. Obtener la MAC de la VM (VMM o `ip link`).
3. Router ASUS:
   - `LAN` -> `DHCP Server` -> “Manually Assigned IP around the DHCP list”.
4. Crear reserva:
   - MAC de la VM -> IP fija (ej. `192.168.50.120`).

## Checklist
- `ssh usuario@192.168.50.120`
