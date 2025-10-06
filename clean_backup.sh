#!/usr/bin/env bash

# set -e: Keluar segera jika ada perintah yang gagal dan tidak berhasil dieksekusi.
set -eo pipefail

# --- Konfigurasi ---
BACKUP_DIR="/home/clp/backups"
LOG_FILE="/home/alwyzon/clean_backup.log"
CLEAN_BACKUP_STATS_FILE="$(mktemp -t clean_backup_stats.XXXXXX 2>/dev/null || printf '/tmp/clean_backup_stats.%s' "$$")"

trap 'rm -f "$CLEAN_BACKUP_STATS_FILE"' EXIT

if [ ! -f "$LOG_FILE" ]; then
    sudo touch "$LOG_FILE"
    sudo chmod 664 "$LOG_FILE"
fi

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

# Fungsi untuk menampilkan animasi spinner yang lebih menarik
spinner() {
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

# Fungsi untuk menampilkan progress bar (untuk operasi yang memakan waktu)
show_progress_bar() {
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

# Fungsi untuk menampilkan pesan dengan delay (efek mengetik)
type_message() {
    local message=$1
    local delay=${2:-0.03}
    
    for ((i=0; i<${#message}; i++)); do
        printf "%s" "${message:$i:1}"
        sleep $delay
    done
    printf "\n"
}

# Fungsi pembungkus untuk menjalankan tugas dengan spinner dan status
# Argumen 1: Deskripsi tugas
# Argumen 2: Perintah yang akan dijalankan
do_task() {
    local description="$1"
    local command="$2"
    local exit_code=0

    # Cetak deskripsi dengan simbol dan warna
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
    else
        echo -e "[${RED}${BOLD} ✗ GAGAL ${NC}]"
        return $exit_code
    fi
}

# Fungsi khusus untuk tugas kompleks (Netdata & Backup)
clean_netdata() {
    sudo systemctl stop netdata
    sudo rm -rf /var/cache/netdata/*
    sudo systemctl start netdata
}

clean_backups() {
    local stats_file="$CLEAN_BACKUP_STATS_FILE"

    if [ ! -d "$BACKUP_DIR" ]; then
        {
            echo "status=missing"
        } > "$stats_file"
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
    
    if [ $folder_count -gt 0 ]; then
        # Hapus folder satu per satu untuk efek visual
        find . -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' folder; do
            rm -rf "$folder"
            sleep 0.1  # Sedikit delay untuk efek visual
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
        echo -e "${YELLOW}Direktori backup ${BACKUP_DIR} tidak ditemukan.${NC}"
        echo "[$timestamp] Backup directory missing: $BACKUP_DIR" | sudo tee -a "$LOG_FILE" > /dev/null
        return
    fi

    local before_hr=$(format_bytes "$before")
    local after_hr=$(format_bytes "$after")
    local deleted_hr=$(format_bytes "$deleted")

    echo -e "${GRAY}Ukuran sebelum pembersihan: ${WHITE}${before_hr} (${before} B)${NC}"
    echo -e "${GRAY}Ukuran setelah pembersihan: ${WHITE}${after_hr} (${after} B)${NC}"
    echo -e "${GRAY}Total ukuran dihapus: ${WHITE}${deleted_hr} (${deleted} B)${NC}"
    echo -e "${GRAY}Folder yang dihapus: ${WHITE}${folders_removed}${NC}"

    printf '[%s] Backup cleanup - before: %s (%s B), after: %s (%s B), freed: %s (%s B), folders removed: %s\n' \
        "$timestamp" "$before_hr" "$before" "$after_hr" "$after" "$deleted_hr" "$deleted" "$folders_removed" | \
        sudo tee -a "$LOG_FILE" > /dev/null
}

# ===================================================================================
# EKSEKUSI UTAMA
# ===================================================================================

# Startup animation
clear
echo -e "${MAGENTA}${BOLD}"
type_message "🚀 Memulai Script Pembersihan Sistem..." 0.05
sleep 0.5

# Header dengan styling menarik
echo -e "\n${MAGENTA}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║${BOLD}${WHITE}                  🧹 SISTEM PEMBERSIHAN 🧹                    ${NC}${MAGENTA}║${NC}"
echo -e "${MAGENTA}║${BOLD}${CYAN}                     Script Otomatis v2.0                     ${NC}${MAGENTA}║${NC}"
echo -e "${MAGENTA}║${GRAY}                    Optimized for Dark Theme                   ${NC}${MAGENTA}║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Simulasi loading awal
show_progress_bar 20 "🔄 Mempersiapkan sistem pembersihan..."
echo

# --- BAGIAN 1: PEMBERSIHAN SISTEM ---
echo -e "${YELLOW}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
echo -e "${YELLOW}${BOLD}│  ${GEAR} PEMBERSIHAN TINGKAT SISTEM ${GRAY}(membutuhkan sudo)${YELLOW}     │${NC}"
echo -e "${YELLOW}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
do_task "Menghapus paket dependensi yang tidak diperlukan" "sudo apt autoremove -y"
do_task "Membersihkan cache paket APT" "sudo apt clean"
do_task "Membersihkan log journal sistem (menjadi maks 100MB)" "sudo journalctl --vacuum-size=100M"

if [ -d "/var/cache/netdata" ]; then
    do_task "Membersihkan cache Netdata" "clean_netdata"
fi


# --- BAGIAN 2: PEMBERSIHAN PENGGUNA ---
echo -e "\n${BLUE}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
echo -e "${BLUE}${BOLD}│  👤 PEMBERSIHAN DIREKTORI PENGGUNA                         │${NC}"
echo -e "${BLUE}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
do_task "Menghapus isi direktori cache pengguna (~/.cache)" "rm -rf ~/.cache/*"


# --- BAGIAN 3: PEMBERSIHAN BACKUP ---
echo -e "\n${GREEN}${BOLD}╭─────────────────────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}${BOLD}│  📁 PEMBERSIHAN DIREKTORI BACKUP SPESIFIK                  │${NC}"
echo -e "${GREEN}${BOLD}╰─────────────────────────────────────────────────────────────╯${NC}\n"
do_task "Menghapus folder backup lama di $BACKUP_DIR" "clean_backups"
report_backup_stats


# Footer dengan animasi selesai
echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║${WHITE}                     ✨ PROSES SELESAI ✨                     ${NC}${GREEN}║${NC}"
echo -e "${GREEN}${BOLD}║${CYAN}                   🎉 Semua tugas berhasil! 🎉                ${NC}${GREEN}║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Tampilkan statistik atau informasi tambahan
echo -e "${GRAY}Script dijalankan pada: ${WHITE}$(date)${NC}"
echo -e "${GRAY}Direktori backup yang dibersihkan: ${WHITE}$BACKUP_DIR${NC}\n"
