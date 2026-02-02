#!/bin/bash

set -euo pipefail

vm="${1:-}"
disk_filename="${2:-}"

libvirt_disk_pool="$LIBVIRT_POOL"
backup_root_destination="$BACKUP_DEST_DIR"
max_file_age="$MAX_BACKUP_FILE_AGE"
accepted_vms_string="$ACCEPTED_VMS"
IFS=',' read -r -a accepted_vms <<< "$accepted_vms_string"

disk_fullpath="$libvirt_disk_pool/$disk_filename"
vm_is_off=false

usage() {
    cat <<EOF
Usage:
    $0 VM_NAME DISK_FILENAME
EOF
}

if [[ -z "$vm" || -z "$disk_filename" ]]; then
    usage
    exit 1
fi

accepted_vm=false
for avm in "${accepted_vms[@]}"; do
    if [[ "$vm" == "$avm" ]]; then
        accepted_vm=true
        break
    fi
done

if ! $accepted_vm; then
    echo "$vm is not in the list of accepted VMs to backup."
    echo "Accepted VMs: ${accepted_vms[*]}"
    exit 1
fi

cleanup() {
    if $vm_is_off; then
        echo "Ensuring $vm is restarted..."
        virsh start "$vm" >/dev/null || true
    fi
}

shutdown_vm() {
    local vm_name="$1"
    local start_time="$SECONDS"
    local max_duration=900
    local max_time="$((start_time+max_duration))"
    echo "Shutting down $vm_name..."
    virsh shutdown "$vm_name" >/dev/null
    until virsh domstate "$vm_name" | grep -q 'shut off'; do
        if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
            return 3 # fail immediately if virsh domstate fails
        fi
        if [[ "$SECONDS" -ge "$max_time" ]]; then
            echo "$vm_name is still running after $((max_duration/60))m, exiting"
            return 1
        fi
        sleep 5
    done
    echo "$vm_name is off."
}

backup_disk() {
    local source="$1"
    local destination="$2"
    local datestamp=$(date +%Y-%m-%d_%H%M%S)
    local filename="$(basename "$source").$datestamp"
    mkdir -p "$destination"
    echo "Backing up $source to $destination..." 
    cp "$source" "$destination/$filename"
    local backup_info=$(ls -lh "$destination/$filename")
    echo "Done: $backup_info"
}

rotate_backups() {
    local backup_root_dir="$1"
    local max_backup_age="$2"
    
    while IFS= read -r -d '' file_to_delete; do
        echo "Deleting $file_to_delete..."
        rm "$file_to_delete"
    done < <(find "$backup_root_dir" -mindepth 1 -maxdepth 1 -mtime +"$max_backup_age" -type f -print0)
}

trap cleanup EXIT
shutdown_vm "$vm" && vm_is_off=true
backup_disk "$disk_fullpath" "$backup_root_destination/$vm"
rotate_backups "$backup_root_destination/$vm" "$max_file_age"
