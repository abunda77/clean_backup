#!/usr/bin/env bash

# set -e: Keluar segera jika ada perintah yang gagal dan tidak berhasil dieksekusi.
set -eo pipefail

# --- Konfigurasi ---
BACKUP_DIR="/home/clp/backups"
LOG_FILE="${LOG_FILE:-/home/alwyzon/clean_backup.log}"
CLEAN_BACKUP_STATS_FILE="$(mktemp -t clean_backup_stats.XXXXXX 2>/dev/null || printf '/tmp/clean_backup_stats.%s' "$$")"

trap 'rm -f "$CLEAN_BACKUP_STATS_FILE"' EXIT

# Fungsi untuk menulis log dengan penanganan error yang lebih baik
write_log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] $message"
    
    # Prioritas 1: Coba tulis ke syslog (paling reliable di cron)
    if logger -t clean_backup "$message" 2>/dev/null; then
        return 0
    fi
    
    # Prioritas 2: Coba tulis ke file log langsung
    if echo "$log_entry" >> "$LOG_FILE" 2>/dev/null; then
        return 0
    fi
    
    # Prioritas 3: Coba dengan sudo
    if echo "$log_entry" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1; then
        return 0
    fi
    
    # Prioritas 4: Coba buat file log dulu dengan sudo
    if sudo touch "$LOG_FILE" 2>/dev/null && sudo chmod 664 "$LOG_FILE" 2>/dev/null; then
        if echo "$log_entry" | sudo tee -a "$LOG_FILE" > /dev/null 2>&1; then
            return 0
        fi
    fi
    
    # Prioritas 5: Fallback ke /tmp
    local fallback_log="/tmp/clean_backup_fallback.log"
    if echo "$log_entry" >> "$fallback_log" 2>/dev/null; then
        return 0
    fi
    
    # Prioritas 6: Terakhir, tulis ke stderr
    echo "$log_entry" >&2
    return 1
}

# Fungsi untuk memastikan script berjalan dengan environment yang benar
setup_environment() {
    # Pastikan PATH lengkap untuk cron
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    
    # Pastikan HOME terdefinisi
    if [ -z "$HOME" ]; then
        export HOME="/home/alwyzon"
    fi
    
    # Log environment info
    write_log "Script started - User: $(whoami), UID: $(id -u), HOME: $HOME"
    write_log "PATH: $PATH"
    write_log "LOG_FILE: $LOG_FILE"
    write_log "BACKUP_DIR: $BACKUP_DIR"
}

# Inisialisasi file log dengan penanganan error yang lebih baik
init_log_file() {
    # Selalu coba tulis ke syslog untuk indikasi script berjalan
    logger -t clean_backup "Script initialization started" 2>/dev/null || true
    
    if [ ! -f "$LOG_FILE" ]; then
        # Coba buat file log tanpa sudo dulu
        if ! touch "$LOG_FILE" 2>/dev/null; then
            # Jika gagal, coba dengan sudo
            if ! sudo touch "$LOG_FILE" 2>/dev/null; then
                # Jika masih gagal, gunakan alternatif
                LOG_FILE="/tmp/clean_backup.log"
                touch "$LOG_FILE" 2>/dev/null || {
                    write_log "Failed to create any log file, using syslog only"
                }
            fi
        fi
        
        # Set permission jika file berhasil dibuat
        if [ -f "$LOG_FILE" ]; then
            chmod 664 "$LOG_FILE" 2>/dev/null || sudo chmod 664 "$LOG_FILE" 2>/dev/null || true
        fi
    fi
    
    write_log "Log file initialized: $LOG_FILE"
}

# ===================================================================================
# DEFINISI WARNA DAN ANIMASI UNTUK TERMINAL GELAP
# ===================================================================================

# Definisi warna yang kontras dengan background gelap
RED='\033[1;31m'          # Merah terang
GREEN='\033[1;32m'        # Hijau terang
YELLOW='\033[1;33m'       # Kuning terang
BLUE='\033[1;34m'         # Biru terang
MAGENTA='\033[1;35m'      # Magenta terang
CYAN='\033[1;36m'         # Cyan terang
WHITE='\033[1;37m'        # Putih terang
GRAY='\033[0;90m'         # Abu-abu gelap
BOLD='\033[1m'            # Tebal
NC='\033[0m'              # No Color (reset)

# Simbol Unicode untuk visual feedback yang menarik
CHECKMARK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
ARROW="${CYAN}➤${NC}"
STAR="${YELLOW}★${NC}"
GEAR="${BLUE}⚙${NC}"
ROCKET="${MAGENTA}🚀${NC}"

# Cek apakah script berjalan di terminal (interaktif) atau cron
is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# Fungsi untuk menampilkan animasi spinner (hanya jika interaktif)
spinner() {
    # Skip spinner jika tidak interaktif (cron)
    if ! is_interactive; then
        return 0
    fi
    
    local pid=$1
    local delay=0.08
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while ps -p $pid > /dev/null; do
        printf "\r${CYAN}%s${NC} " "${spinstr:$i:1}"
        i=$(( (i+1) % ${#spinstr} ))
        sleep $delay
    done
    printf "\r   \r" # Hapus spinner
}

format_bytes() {
    local bytes=${1:-0}
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec --suffix=B "$bytes"
    else
        echo "${bytes} B"
    fi
}

# Fungsi untuk menampilkan progress bar (hanya jika interaktif)
show_progress_bar() {
    # Skip progress bar jika tidak interaktif (cron)
    if ! is_interactive; then
        write_log "Progress: $2"
        return 0
    fi
    
    local duration=$1
    local msg=$2
    local width=40
    
    echo -e "${CYAN}${msg}${NC}"
    for ((i=0; i<=duration; i++)); do
        local progress=$((i * width / duration))
        local bar=$(printf "%*s" $progress | tr ' ' '█')
        local spaces=$(printf "%*s" $((width - progress)))
        local percent=$((i * 100 / duration))
        
        printf "\r${GREEN}${bar}${GRAY}${spaces}${NC} ${YELLOW}${percent}%%${NC}"
        sleep 0.1
    done
    printf "\n"
}

# Fungsi untuk menampilkan pesan dengan delay (hanya jika interaktif)
type_message() {
    # Skip typing effect jika tidak interaktif (cron)
    if ! is_interactive; then
        echo "$1"
        return 0
    fi
    
    local message=$1
    local delay=${2:-0.03}
    
    for ((i=0; i<${#message}; i++)); do
        printf "%s" "${message:$i:1}"
        sleep $delay
    done
    printf "\n"
}

# Fungsi pembungkus untuk menjalankan tugas dengan spinner dan status
do_task() {
    local description="$1"
    local command="$2"
    local exit_code=0

    # Log task start
    write_log "Starting task: $description"

    # Jika tidak interaktif, jalankan langsung tanpa spinner
    if ! is_interactive; then
        if eval "$command"; then
            write_log "Task completed successfully: $description"
            return 0
        else
            exit_code=$?
            write_log "Task failed: $description (exit code: $exit_code)"
            return $exit_code
        fi
    fi

    # Mode interaktif: tampilkan spinner
    printf "${ARROW} %-60s" "$description"

    # Jalankan perintah di background, sembunyikan outputnya agar tidak mengganggu spinner
    eval "$command" &> /dev/null &
    
    # Jalankan spinner selagi perintah di background bekerja
    spinner $!

    # Tunggu perintah selesai dan tangkap status keluarnya
    wait $! || exit_code=$?

    # Cetak status berdasarkan exit code dengan simbol yang menarik
    if [ $exit_code -eq 0 ]; then
        echo -e "[${GREEN}${BOLD} ✓ SUKSES ${NC}]"
        write_log "Task completed successfully: $description"
    else
        echo -e "[${RED}${BOLD} ✗ GAGAL ${NC}]"
        write_log "Task failed: $description (exit code: $exit_code)"
        return $exit_code
    fi
}

# Fungsi khusus untuk tugas kompleks (Netdata & Backup)
clean_netdata() {
    if systemctl is-active --quiet netdata; then
        sudo systemctl stop netdata
        sudo rm -rf /var/cache/netdata/*
        sudo systemctl start netdata
        write_log "Netdata cache cleaned successfully"
    else
        write_log "Netdata is not running, skipping cache cleanup"
    fi
}

clean_backups() {
    local stats_file="$CLEAN_BACKUP_STATS_FILE"

    if [ ! -d "$BACKUP_DIR" ]; then
        {
            echo "status=missing"
        } > "$stats_file"
        write_log "Backup directory not found: $BACKUP_DIR"
        return 0
    fi
    
    cd "$BACKUP_DIR" || return 1
    
    local before_bytes=$(du -sb . 2>/dev/null | awk '{print $1}')
    if [ -z "$before_bytes" ]; then
        before_bytes=0
    fi

    # Hitung jumlah folder sebelum dihapus
    local folder_count=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
    local removed_count=0
    
    write_log "Found $folder_count backup folders to clean"
    
    if [ $folder_count -gt 0 ]; then
        # Hapus folder satu per satu
        find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' folder; do
            folder_name=$(basename "$folder")
            write_log "Removing backup folder: $folder_name"
            rm -rf "$folder"
            sleep 0.1  # Sedikit delay untuk efek visual (hanya di mode interaktif)
        done
        removed_count=$folder_count
    fi

    local after_bytes=$(du -sb . 2>/dev/null | awk '{print $1}')
    if [ -z "$after_bytes" ]; then
        after_bytes=0
    fi

    local deleted_bytes=$((before_bytes - after_bytes))
    if [ "$deleted_bytes" -lt 0 ]; then
        deleted_bytes=0
    fi

    cat <<EOF > "$stats_file"
status=ok
before=$before_bytes
after=$after_bytes
deleted=$deleted_bytes
folders_removed=$removed_count
EOF
    
    write_log "Backup cleanup completed - removed $removed_count folders, freed $(format_bytes $deleted_bytes)"
}

report_backup_stats() {
    local stats_file="$CLEAN_BACKUP_STATS_FILE"

    if [ ! -f "$stats_file" ]; then
        return
    fi

    local status="" before="0" after="0" deleted="0" folders_removed="0"

    while IFS='=' read -r key value; do
        case "$key" in
            status) status="$value" ;;
            before) before="$value" ;;
            after) after="$value" ;;
            deleted) deleted="$value" ;;
            folders_removed) folders_removed="$value" ;;
        esac
    done < "$stats_file"

    rm -f "$stats_file"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    if [ "$status" = "missing" ]; then
        if is_interactive; then
            echo -e "${YELLOW}Direktori backup ${BACKUP_DIR} tidak ditemukan.${NC}"
        fi
        write_log "Backup directory missing: $BACKUP_DIR"
        return
    fi

    local before_hr=$(format_bytes "$before")
    local after_hr=$(format_bytes "$after")
    local deleted_hr=$(format_bytes "$deleted")

    if is_interactive; then
        echo -e "${GRAY}Ukuran sebelum pembersihan: ${WHITE}${before_hr} (${before} B)${NC}"
        echo -e "${GRAY}Ukuran setelah pembersihan: ${WHITE}${after_hr} (${after} B)${NC}"
        echo -e "${GRAY}Total ukuran dihapus: ${WHITE}${deleted_hr} (${deleted} B)${NC}"
        echo -e "${GRAY}Folder yang dihapus: ${WHITE}${folders_removed}${NC}"
    fi

    write_log "Backup cleanup - before: $before_hr ($before B), after: $after_hr ($after B), freed: $deleted_hr ($deleted B), folders removed: $folders_removed"
}

# ===================================================================================
# EKSEKUSI UTAMA
# ===================================================================================

# Setup environment dan logging
setup_environment
init_log_file

# Log script start
write_log "=== CLEAN BACKUP SCRIPT STARTED ==="

# Startup animation (hanya jika interaktif)
if is_interactive; then
    clear
    echo -e "${MAGENTA}${BOLD}"
    type_message "🚀 Memulai Script Pembersihan Sistem..." 0.05
    sleep 0.5

    # Header dengan styling menarik
    echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${BOLD}${WHITE}                  🧹 SISTEM PEMBERSIHAN 🧹                    ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${BOLD}${CYAN}                     Script Otomatis v2.1                     ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}║${GRAY}                    Optimized for Dark Theme                   ${NC}${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}\n"

    # Simulasi loading awal
    show_progress_bar 20 "🔄 Mempersiapkan sistem pembersihan..."
    echo
else
    write_log "Running in non-interactive mode (cron)"
fi

# --- BAGIAN 1: PEMBERSIHAN SISTEM ---
if is_interactive; then
    echo -e "${YELLOW}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${YELLOW}${BOLD}│  ${GEAR} PEMBERSIHAN TINGKAT SISTEM ${GRAY}(membutuhkan sudo)${YELLOW}     │${NC}"
    echo -e "${YELLOW}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
fi

do_task "Menghapus paket dependensi yang tidak diperlukan" "sudo apt autoremove -y"
do_task "Membersihkan cache paket APT" "sudo apt clean"
do_task "Membersihkan log journal sistem (menjadi maks 100MB)" "sudo journalctl --vacuum-size=100M"

if [ -d "/var/cache/netdata" ]; then
    do_task "Membersihkan cache Netdata" "clean_netdata"
fi

# --- BAGIAN 2: PEMBERSIHAN PENGGUNA ---
if is_interactive; then
    echo -e "\n${BLUE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${BLUE}${BOLD}│  👤 PEMBERSIHAN DIREKTORI PENGGUNA                         │${NC}"
    echo -e "${BLUE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
fi

do_task "Menghapus isi direktori cache pengguna (~/.cache)" "rm -rf ~/.cache/*"

# --- BAGIAN 3: PEMBERSIHAN BACKUP ---
if is_interactive; then
    echo -e "\n${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${GREEN}${BOLD}│  📁 PEMBERSIHAN DIREKTORI BACKUP SPESIFIK                  │${NC}"
    echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
fi

do_task "Menghapus folder backup lama di $BACKUP_DIR" "clean_backups"
report_backup_stats

# Footer dengan animasi selesai (hanya jika interaktif)
if is_interactive; then
    echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║${WHITE}                     ✨ PROSES SELESAI ✨                     ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}${BOLD}║${CYAN}                   🎉 Semua tugas berhasil! 🎉                ${NC}${GREEN}║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"

    # Tampilkan statistik atau informasi tambahan
    echo -e "${GRAY}Script dijalankan pada: ${WHITE}$(date)${NC}"
    echo -e "${GRAY}Direktori backup yang dibersihkan: ${WHITE}$BACKUP_DIR${NC}\n"
fi

# Log script completion
write_log "=== CLEAN BACKUP SCRIPT COMPLETED SUCCESSFULLY ==="