#!/bin/bash
set -o pipefail

# Configuration file (bash-backup-files.conf) must be in the same directory as this script.
CONFIG_FILE="$(dirname "$0")/bash-backup-files.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Configuration file $CONFIG_FILE not found."
    exit 1
fi

# Ensure required configuration is set.
# PROJECTS is expected to be an array with each element formatted as "project_name:path"
if [ "${#PROJECTS[@]}" -eq 0 ]; then
    echo "No projects defined in the configuration. Check bash-backup-files.conf."
    exit 1
fi

# Default log file location
LOG_FILE="/var/log/backups.log"

# Format backup date
BACKUP_DATE=$(date +%Y%m%d-%H%M)

# Counter for errors
ERROR_COUNT=0
DRY_RUN=false

# Process command line options (these may override configuration values)
while getopts "m:l:b:k:T:h:n" opt; do
    case $opt in
        m) MODE=$OPTARG ;;
        l) LOCAL_PATH=$OPTARG ;;
        b) CLOUD_BUCKET=$OPTARG ;;
        k) ENCRYPTION_KEY=$OPTARG ;;
        T) RETENTION_DAYS=$OPTARG ;;
        h) REMOTE_HOST=$OPTARG ;;
        n) DRY_RUN=true ;;
        *)
cat << 'EOF'
Usage: $0 [options]

Options:
  -m  Mode of backup. Valid options:
         local -> Backup to a local directory.
         s3    -> Backup to an AWS S3 bucket.
         gcp   -> Backup to a Google Cloud Storage bucket.
         
  -l  Backup path:
         For 'local', this is the destination folder on the system.
         For remote transfers (with -h), this is the folder on the remote host.
         
  -b  Cloud bucket path (for gcp and s3 modes).
         
  -k  Encryption key for GPG symmetric encryption (AES256).
  
  -T  Retention days: number of days to keep backup files.
  
  -h  Remote host for transferring backups (format: user@host).

  -n  Dry run: log operations without creating, uploading, or deleting backups.

Examples:
  $0 -m local -l /backups/files -T 7
  $0 -m gcp -b gs://my-bucket/path -k mysecret
  $0 -m local -l /backups/files -h user@remotehost

EOF
exit 1
;;
    esac
done
shift $((OPTIND - 1))

if [ "$MODE" == "gcp" ] && ! command -v gcloud >/dev/null 2>&1; then
    echo "gcloud command not found. Install the Google Cloud CLI before using GCP mode."
    exit 1
fi

# Function for logging with timestamp
log_check_message() {
    local timestamp
    timestamp=$(date '+%a %b %e %T %Y')
    local log_message="[${timestamp}] $1"
    echo "$log_message" >> "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[${timestamp}] [error] Error occurred during logging: $1" >> "$LOG_FILE"
        exit 1
    fi
}

# Function to perform backup for a specific project.
# Parameters:
#   $1: Project name (used for naming the backup file)
#   $2: Path to back up
backup_item() {
    local project="$1"
    local item="$2"
    local ext=".tar.gz"
    if [ -n "$ENCRYPTION_KEY" ]; then
        ext=".tar.gz.gpg"
    fi
    local file_name="${project}-${BACKUP_DATE}${ext}"

    log_check_message "[info] Starting backup of ${item} (project: ${project})"

    if [ "$DRY_RUN" == "true" ]; then
        log_check_message "[dry-run] Would create and upload ${file_name} using mode ${MODE}"
        return 0
    fi

    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            # Remote backup via SSH
            local tmp_backup="/tmp/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                tar czf - "$item" 2>/dev/null | \
                gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" -o "$tmp_backup"
            else
                tar czf "$tmp_backup" "$item" 2>/dev/null
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error creating temporary backup for ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
                rm -f "$tmp_backup"
                return 1
            fi
            log_check_message "[info] Transferring backup of ${item} to remote host ${REMOTE_HOST}:${LOCAL_PATH}"
            scp "$tmp_backup" "${REMOTE_HOST}:${LOCAL_PATH}/${file_name}"
            if [ $? -ne 0 ]; then
                log_check_message "[error] Remote transfer failed for backup of ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Backup of ${item} transferred successfully to remote host"
            fi
            rm -f "$tmp_backup"
        else
            # Local backup on filesystem
            mkdir -p "$LOCAL_PATH"
            local backup_file="${LOCAL_PATH}/${file_name}"
            if [ -n "$ENCRYPTION_KEY" ]; then
                tar czf - "$item" 2>/dev/null | \
                gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" -o "$backup_file"
            else
                tar czf "$backup_file" "$item" 2>/dev/null
            fi
            if [ $? -ne 0 ]; then
                log_check_message "[error] Error during local backup of ${item}"
                ERROR_COUNT=$((ERROR_COUNT+1))
            else
                log_check_message "[info] Local backup of ${item} completed: ${backup_file}"
            fi
        fi
    elif [ "$MODE" == "s3" ]; then
        # Backup to AWS S3 using AWS CLI
        local remote_file="${project}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            tar czf - "$item" 2>/dev/null | \
            gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" | \
            aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            tar czf - "$item" 2>/dev/null | aws s3 cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error with S3 backup for ${item}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] S3 backup of ${item} completed: ${remote_file}"
        fi
    elif [ "$MODE" == "gcp" ]; then
        # Backup to GCP using gcloud storage
        local remote_file="${project}/${file_name}"
        if [ -n "$ENCRYPTION_KEY" ]; then
            tar czf - "$item" 2>/dev/null | \
            gpg --batch --yes --symmetric --cipher-algo AES256 --passphrase "$ENCRYPTION_KEY" | \
            gcloud storage cp - "${CLOUD_BUCKET}/${remote_file}"
        else
            tar czf - "$item" 2>/dev/null | gcloud storage cp - "${CLOUD_BUCKET}/${remote_file}"
        fi
        if [ $? -ne 0 ]; then
            log_check_message "[error] Error with GCP backup for ${item}"
            ERROR_COUNT=$((ERROR_COUNT+1))
        else
            log_check_message "[info] GCP backup of ${item} completed: ${remote_file}"
        fi
    else
        echo "Unknown mode: $MODE. Valid options: local, s3, gcp"
        exit 1
    fi
}

# Function to apply the retention policy on local backups (or remote backups via SSH)
apply_retention_policy() {
    if [ "$DRY_RUN" == "true" ]; then
        log_check_message "[dry-run] Would apply retention policy for mode ${MODE} (${RETENTION_DAYS} days)."
        return 0
    fi

    log_check_message "[info] Applying retention policy: deleting backups older than ${RETENTION_DAYS} days."
    if [ "$MODE" == "local" ]; then
        if [ -n "$REMOTE_HOST" ]; then
            ssh "$REMOTE_HOST" "find \"$LOCAL_PATH\" -type f -mtime +${RETENTION_DAYS} -delete"
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied on remote destination."
            else
                log_check_message "[error] Retention policy failed on remote host."
            fi
        else
            find "$LOCAL_PATH" -type f -mtime +${RETENTION_DAYS} -delete
            if [ $? -eq 0 ]; then
                log_check_message "[info] Retention policy applied on local destination."
            else
                log_check_message "[error] Retention policy failed locally."
            fi
        fi
    else
        log_check_message "[info] Retention policy does not apply for mode ${MODE}."
    fi
}

# Main function to coordinate the backup process.
# It iterates over each project defined in the PROJECTS array.
main() {
    for entry in "${PROJECTS[@]}"; do
        # Each entry is expected to be "project_name:path"
        project="${entry%%:*}"
        path="${entry#*:}"
        # Remove any extra spaces.
        project=$(echo "$project" | xargs)
        path=$(echo "$path" | xargs)
        if [ -n "$project" ] && [ -n "$path" ]; then
            if [ -e "$path" ]; then
                backup_item "$project" "$path"
            else
                log_check_message "[error] Backup target '$path' (project: $project) does not exist"
                ERROR_COUNT=$((ERROR_COUNT+1))
            fi
        fi
    done

    apply_retention_policy

    if [ $ERROR_COUNT -gt 0 ]; then
        log_check_message "[error] Process finished with ${ERROR_COUNT} errors."
        exit 1
    else
        log_check_message "[info] All backups completed successfully."
        exit 0
    fi
}

main
