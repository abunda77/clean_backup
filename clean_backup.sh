#!/usr/bin/env bash

# set -e: Keluar segera jika ada perintah yang gagal.
set -eo pipefail

# --- Konfigurasi ---
BACKUP_DIR="/home/clp/backups"

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
    if [ ! -d "$BACKUP_DIR" ]; then
        return 0 # Kembali dengan sukses karena ini bukan error
    fi
    cd "$BACKUP_DIR" || return 1
    
    # Hitung jumlah folder sebelum dihapus
    local folder_count=$(find . -mindepth 1 -maxdepth 1 -type d | wc -l)
    
    if [ $folder_count -gt 0 ]; then
        # Hapus folder satu per satu untuk efek visual
        find . -mindepth 1 -maxdepth 1 -type d | while read -r folder; do
            rm -rf "$folder"
            sleep 0.1  # Sedikit delay untuk efek visual
        done
    fi
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


# Footer dengan animasi selesai
echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║${WHITE}                     ✨ PROSES SELESAI ✨                     ${NC}${GREEN}║${NC}"
echo -e "${GREEN}${BOLD}║${CYAN}                   🎉 Semua tugas berhasil! 🎉                ${NC}${GREEN}║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Tampilkan statistik atau informasi tambahan
echo -e "${GRAY}Script dijalankan pada: ${WHITE}$(date)${NC}"
echo -e "${GRAY}Direktori backup yang dibersihkan: ${WHITE}$BACKUP_DIR${NC}\n"
