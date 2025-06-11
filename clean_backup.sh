#!/usr/bin/env bash

BACKUP_DIR="/home/clp/backups"

cd "$BACKUP_DIR" || { echo "ERROR: Gagal masuk ke $BACKUP_DIR"; exit 1; }

# hapus semua folder di dalamnya
ls -1d */ 2>/dev/null | xargs -r rm -rf --
