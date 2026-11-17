[English](#english-documentation) | [Español](#documentación-en-español)

# Backup Script Documentation

## English Documentation

This backup script backs up files or directories defined in a simple configuration file named `bash-backup-files.conf`. Instead of using separate arrays or JSON, the configuration groups the project name and the path together in a single array. Each element in the array is formatted as:

   project_name:path

For example:

   PROJECTS=(
     "project1:/etc/mysql"
     "project2:/var/www"
   )

### Features

- **Grouping of Values:**  
  Each project is defined as a single element combining the project name and its path, separated by a colon.

- **Compression & Encryption:**  
  The script creates backups using tar with gzip compression. If an encryption key (`ENCRYPTION_KEY`) is provided in the configuration, the backup will be encrypted with GPG using AES256 symmetric encryption.

- **Multiple Backup Modes:**  
  The script supports backup modes:

    - **local:** Store backups on a local directory. Optionally, they can be transferred via SSH to a remote host if `REMOTE_HOST` is defined.
    - **s3:** Upload backups to an AWS S3 bucket.
    - **gcp:** Upload backups to a Google Cloud Storage bucket using `gcloud storage`.

- **Retention Policy:**  
  Backups older than the specified number of days (`RETENTION_DAYS`) are automatically deleted.

### How to Use

1. **Edit the Configuration File:**  
   Create or modify `bash-backup-files.conf` and define the projects array along with other variables such as `LOCAL_PATH`, `CLOUD_BUCKET`, `REMOTE_HOST`, etc.

2. **Run the Script:**  
   Execute the backup script (e.g., `./bash-backup-files.sh`) with command line options that can override the configuration if needed:

   - `-m`: Backup mode (`local`, `s3`, or `gcp`).
   - `-l`: Local backup path.
   - `-b`: Cloud bucket path (for s3 or gcp modes).
   - `-k`: Encryption key for GPG (AES256).
    - `-T`: Retention days.
    - `-h`: Remote host for SSH transfers.
    - `-n`: Dry run; log operations without creating, uploading, or deleting backups.

   GCP mode requires the Google Cloud CLI and an authenticated `gcloud` configuration
   for the user that runs the script (including the cron user).

**Example Command:**

   ./bash-backup-files.sh -m local -l /backups/files -T 7

## Documentación en Español

Este script de backup respalda archivos o directorios definidos en un archivo de configuración sencillo llamado `bash-backup-files.conf`. En lugar de usar arrays separados o JSON, la configuración agrupa el nombre del proyecto y la ruta en un solo array. Cada elemento del array se formatea de la siguiente manera:

   nombre_proyecto:ruta

Por ejemplo:

   PROJECTS=(
     "proyecto1:/etc/mysql"
     "proyecto2:/var/www"
   )

### Características

- **Agrupación de Valores:**  
  Cada proyecto se define como un solo elemento que combina el nombre del proyecto y su ruta, separados por dos puntos.

- **Compresión y Encriptación:**  
  El script crea backups usando tar con compresión gzip. Si se provee una clave de encriptación (`ENCRYPTION_KEY`) en la configuración, el backup se encripta con GPG utilizando encriptación simétrica AES256.

- **Modos de Respaldo Múltiples:**  
  El script soporta los siguientes modos de backup:

    - **local:** Guarda el backup en un directorio local. Opcionalmente, puede transferirse vía SSH a un host remoto si se define `REMOTE_HOST`.
    - **s3:** Sube el backup a un bucket de AWS S3.
     - **gcp:** Sube el backup a un bucket de Google Cloud Storage usando `gcloud storage`.

- **Política de Retención:**  
  Se eliminan automáticamente los backups que sean más antiguos que la cantidad de días especificada (`RETENTION_DAYS`).

### Cómo Usarlo

1. **Editar el Archivo de Configuración:**  
   Crea o modifica el archivo `bash-backup-files.conf` y define el array de proyectos junto con otras variables como `LOCAL_PATH`, `CLOUD_BUCKET`, `REMOTE_HOST`, etc.

2. **Ejecutar el Script:**  
   Ejecuta el script de backup (por ejemplo, `./bash-backup-files.sh`) utilizando opciones en línea de comandos que puedan sobreescribir la configuración:

   - `-m`: Modo de backup (`local`, `s3` o `gcp`).
   - `-l`: Ruta local para el backup.
   - `-b`: Ruta del bucket en la nube (para s3 o gcp).
   - `-k`: Clave de encriptación para GPG (AES256).
    - `-T`: Días de retención.
    - `-h`: Host remoto para transferencias vía SSH.
    - `-n`: Dry run; registra las operaciones sin crear, subir ni borrar backups.

   El modo GCP requiere Google Cloud CLI y una configuración `gcloud` autenticada
   para el usuario que ejecuta el script (incluido el usuario del cron).

**Ejemplo de Comando:**

   ./bash-backup-files.sh -m local -l /backups/files -T 7
