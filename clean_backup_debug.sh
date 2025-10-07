#!/usr/bin/env bash

# Debug version untuk mengidentifikasi masalah cron job
set -eo pipefail

# Konfigurasi
BACKUP_DIR="/home/clp/backups"
LOG_FILE="${LOG_FILE:-/home/alwyzon/clean_backup.log}"
DEBUG_LOG="/tmp/clean_backup_debug.log"

# Fungsi untuk menulis debug log
write_debug_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] DEBUG: $message" >> "$DEBUG_LOG"
    # Juga tulis ke syslog untuk visibility
    logger -t clean_backup_debug "$message" 2>/dev/null || echo "[$timestamp] DEBUG: $message" >&2
}

# Mulai debugging
write_debug_log "=== SCRIPT DIMULAI ==="
write_debug_log "User: $(whoami)"
write_debug_log "UID: $(id -u)"
write_debug_log "Home directory: $HOME"
write_debug_log "Current directory: $(pwd)"
write_debug_log "Script path: $0"
write_debug_log "LOG_FILE: $LOG_FILE"
write_debug_log "BACKUP_DIR: $BACKUP_DIR"

# Cek environment variables penting
write_debug_log "PATH: $PATH"
write_debug_log "SUDO_USER: ${SUDO_USER:-not set}"
write_debug_log "SUDO_UID: ${SUDO_UID:-not set}"
write_debug_log "SUDO_GID: ${SUDO_GID:-not set}"

# Cek permission direktori log
LOG_DIR=$(dirname "$LOG_FILE")
write_debug_log "Log directory: $LOG_DIR"
if [ -d "$LOG_DIR" ]; then
    write_debug_log "Log directory exists: YES"
    write_debug_log "Log directory permissions: $(ls -ld "$LOG_DIR")"
    write_debug_log "Log directory owner: $(stat -c '%U:%G' "$LOG_DIR" 2>/dev/null || echo 'unknown')"
    write_debug_log "Can write to log directory: $([ -w "$LOG_DIR" ] && echo 'YES' || echo 'NO')"
else
    write_debug_log "Log directory exists: NO"
fi

# Cek file log
if [ -f "$LOG_FILE" ]; then
    write_debug_log "Log file exists: YES"
    write_debug_log "Log file permissions: $(ls -l "$LOG_FILE")"
    write_debug_log "Log file owner: $(stat -c '%U:%G' "$LOG_FILE" 2>/dev/null || echo 'unknown')"
    write_debug_log "Can write to log file: $([ -w "$LOG_FILE" ] && echo 'YES' || echo 'NO')"
else
    write_debug_log "Log file exists: NO"
fi

# Cek backup directory
if [ -d "$BACKUP_DIR" ]; then
    write_debug_log "Backup directory exists: YES"
    write_debug_log "Backup directory permissions: $(ls -ld "$BACKUP_DIR")"
    write_debug_log "Backup directory owner: $(stat -c '%U:%G' "$BACKUP_DIR" 2>/dev/null || echo 'unknown')"
    write_debug_log "Can write to backup directory: $([ -w "$BACKUP_DIR" ] && echo 'YES' || echo 'NO')"
    
    # Cek isi backup directory
    local folder_count=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    write_debug_log "Number of backup folders: $folder_count"
    
    if [ $folder_count -gt 0 ]; then
        write_debug_log "Backup folders found:"
        find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -5 | while read folder; do
            write_debug_log "  - $(basename "$folder")"
        done
    fi
else
    write_debug_log "Backup directory exists: NO"
fi

# Cek ketersediaan perintah penting
for cmd in sudo apt rm journalctl logger du find; do
    if command -v "$cmd" >/dev/null 2>&1; then
        write_debug_log "Command '$cmd' available: YES"
    else
        write_debug_log "Command '$cmd' available: NO"
    fi
done

# Cek sudo access
write_debug_log "Testing sudo access..."
if sudo -n true 2>/dev/null; then
    write_debug_log "Sudo access (no password): YES"
else
    write_debug_log "Sudo access (no password): NO"
    # Coba dengan password (ini akan gagal tapi memberi info)
    if echo "testing" | sudo -S true 2>/dev/null; then
        write_debug_log "Sudo access (with password): YES"
    else
        write_debug_log "Sudo access (with password): NO or wrong password"
    fi
fi

# Test write ke log file
write_debug_log "Testing log file write..."
test_message="Test write at $(date)"
if echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST: $test_message" >> "$LOG_FILE" 2>/dev/null; then
    write_debug_log "Direct log write: SUCCESS"
else
    write_debug_log "Direct log write: FAILED"
    # Coba dengan sudo
    if echo "[$(date '+%Y-%m-%d %H:%M:%S')] TEST: $test_message" | sudo tee -a "$LOG_FILE" >/dev/null 2>&1; then
        write_debug_log "Sudo log write: SUCCESS"
    else
        write_debug_log "Sudo log write: FAILED"
    fi
fi

# Test operasi sederhana
write_debug_log "Testing simple operations..."
if rm -rf /tmp/test_clean_backup_* 2>/dev/null; then
    write_debug_log "Simple rm operation: SUCCESS"
else
    write_debug_log "Simple rm operation: FAILED"
fi

write_debug_log "=== SCRIPT SELESAI ==="