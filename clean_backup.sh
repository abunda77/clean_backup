#!/usr/bin/env bash

BACKUP_DIR="/home/clp/backups"

cd "$BACKUP_DIR" || { echo "ERROR: Gagal masuk ke $BACKUP_DIR"; exit 1; }

# hapus semua folder di dalamnya
FOLDERS=$(ls -1d */ 2>/dev/null)

if [ -z "$FOLDERS" ]; then
    echo "INFO: Tidak ada folder yang perlu dihapus"
else
    ls -1d */ 2>/dev/null | xargs -r rm -rf --
    if [ $? -eq 0 ]; then
        echo "SUCCESS: Semua folder berhasil dihapus"
    else
        echo "ERROR: Gagal menghapus beberapa folder"
        exit 1
    fi
fi
