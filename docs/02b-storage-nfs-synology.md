# 02b - Storage NFS en Synology para MicroK8s (paso a paso)

## Objetivo

Dejar configurado **NFS en Synology** como almacenamiento para MicroK8s, usando un **StorageClass dinámico** (`nfs-storage`) en lugar de `hostpath-storage`, adecuado para un entorno productivo en una única VM con NAS.

---

## A) Configurar NFS en Synology

1. **Activar NFS en DSM**
   - Panel de control → `File Services` → pestaña **NFS**.
   - Marcar **Enable NFS service**.
   - Protocolo máximo: `NFSv3` (suficiente para este uso).

2. **Crear carpeta compartida para Kubernetes**
   - Panel de control → `Shared Folder` → `Create`.
   - Nombre sugerido: `k8s` (en `volume1`).
   - No activar **data checksum** (no recomendado para bases de datos/VMs).

3. **Dar permisos NFS a la carpeta**
   - Seleccionar la carpeta `k8s` → `Edit` → pestaña **NFS Permissions**.
   - `Create`:
     - **Hostname or IP**: `192.168.50.0/24` (toda la LAN) o `192.168.50.237` (solo la VM de MicroK8s).
     - **Privilege**: `Read/Write`.
     - **Squash**: `Map all users to admin`.
     - **Security**: `sys`.
     - Dejar `Enable asynchronous` marcado.
   - Guardar todo con `Save`.

4. **Verificar exports desde la VM**
   ```bash
   sudo apt update
   sudo apt install -y nfs-common

   showmount -e 192.168.50.254
   ```
   - Debe aparecer algo como:
     - `/volume1/k8s  192.168.50.0/24`

---

## B) Probar montaje NFS desde la VM

```bash
sudo mkdir -p /mnt/nas-k8s
sudo mount -t nfs -o vers=3 192.168.50.254:/volume1/k8s /mnt/nas-k8s
touch /mnt/nas-k8s/_test_from_vm
ls -la /mnt/nas-k8s
sudo umount /mnt/nas-k8s
```

Si el `touch` y el `ls` funcionan, la VM tiene acceso de lectura/escritura al NAS por NFS.

---

## C) Deshabilitar hostpath-storage (solo si ya estaba habilitado)

```bash
microk8s disable hostpath-storage
```

---

## D) Instalar provisioner NFS como StorageClass por defecto

1. **Añadir repositorio Helm**
   ```bash
   microk8s helm3 repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
   microk8s helm3 repo update
   ```

2. **Instalar el chart**
   ```bash
   microk8s helm3 install nfs-nas nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
     --namespace storage-nfs --create-namespace \
     --set nfs.server=192.168.50.254 \
     --set nfs.path=/volume1/k8s \
     --set storageClass.name=nfs-storage \
     --set storageClass.defaultClass=true
   ```

3. **Verificar StorageClass por defecto**
   ```bash
   microk8s kubectl get storageclass
   ```
   - Debe aparecer `nfs-storage (default)` con provisioner `cluster.local/nfs-nas-nfs-subdir-external-provisioner`.

---

## E) Prueba rápida de PVC

1. Crear un archivo `pvc-nfs-test.yaml`:
   ```yaml
   apiVersion: v1
   kind: PersistentVolumeClaim
   metadata:
     name: pvc-nfs-test
   spec:
     accessModes:
       - ReadWriteOnce
     resources:
       requests:
         storage: 1Gi
   ```

2. Aplicar y comprobar:
   ```bash
   microk8s kubectl apply -f pvc-nfs-test.yaml
   microk8s kubectl get pvc pvc-nfs-test
   ```
   - El estado debe ser `Bound`.

3. Confirmar que se creó un subdirectorio en el NAS dentro de `/volume1/k8s`.

4. (Opcional) Limpiar:
   ```bash
   microk8s kubectl delete pvc pvc-nfs-test
   ```

Con esto, MicroK8s queda usando `nfs-storage` (Synology) como almacenamiento dinámico por defecto para tus aplicaciones.

