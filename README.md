# 🧹 Clean Backup Script v2.0

Script pembersihan sistem dengan antarmuka visual yang menarik dan animasi modern untuk terminal gelap.

## 📋 Deskripsi

`clean_backup.sh` adalah script bash interaktif yang dirancang untuk melakukan pembersihan komprehensif pada sistem Linux dengan tiga tahap utama:

1. **🔧 Pembersihan Sistem** - Membersihkan cache sistem, paket tidak terpakai, dan log
2. **👤 Pembersihan Direktori Pengguna** - Menghapus cache pengguna
3. **📁 Pembersihan Direktori Backup** - Menghapus folder backup lama

## ✨ Fitur Utama

### 🎨 **Antarmuka Visual Modern**
- **Warna kontras tinggi** untuk terminal dengan background gelap
- **Animasi spinner** dengan karakter Braille yang smooth
- **Progress bar** untuk operasi yang memakan waktu
- **Simbol Unicode** untuk feedback visual yang menarik (✓, ✗, ➤, ⚙, 🚀)
- **Box drawing characters** untuk border yang elegan

### 🔄 **Animasi & Feedback**
- **Startup animation** dengan efek typing
- **Loading progress bar** untuk persiapan sistem
- **Real-time status** dengan simbol sukses/gagal yang jelas
- **Smooth spinner animation** selama proses berjalan

### 🛠️ **Fungsi Pembersihan**

#### 1. Pembersihan Sistem (Membutuhkan sudo)
- Menghapus paket dependensi yang tidak diperlukan (`apt autoremove`)
- Membersihkan cache paket APT (`apt clean`)
- Membersihkan log journal sistem lama (maksimal 100MB)
- Membersihkan cache Netdata (jika ada) dengan restart service

#### 2. Pembersihan Direktori Pengguna
- Menghapus isi direktori `~/.cache` dengan feedback visual

#### 3. Pembersihan Direktori Backup
- Menghapus semua folder di direktori backup yang dikonfigurasi
- Penghapusan bertahap dengan efek visual
- Verifikasi keberhasilan penghapusan

## Konfigurasi

Sebelum menjalankan script, ubah konfigurasi berikut sesuai kebutuhan:

```bash
BACKUP_DIR="/home/clp/backups"
```

Ganti path di atas dengan lokasi direktori backup Anda.

## Cara Penggunaan

1. Pastikan script memiliki permission untuk dieksekusi:
   ```bash
   chmod +x clean_backup.sh
   ```

2. Jalankan script:
   ```bash
   ./clean_backup.sh
   ```

3. Masukkan password sudo ketika diminta (untuk pembersihan sistem)

## 📋 Persyaratan

- **Sistem Operasi**: Linux (Ubuntu/Debian)
- **Shell**: Bash 4.0+ (untuk dukungan Unicode penuh)
- **Terminal**: Terminal yang mendukung warna ANSI dan Unicode
- **Permissions**: Akses sudo untuk pembersihan sistem
- **Optimal pada**: Terminal dengan background gelap

## ⚠️ Peringatan Penting

> **PERHATIAN SEBELUM MENJALANKAN SCRIPT!**

- 🗑️ Script ini akan **menghapus semua folder** di direktori backup yang dikonfigurasi
- 🗂️ **Cache pengguna akan dihapus** (aplikasi mungkin perlu membuat ulang cache)
- 📊 **Data historis monitoring Netdata akan hilang** jika dibersihkan
- 💾 **Pastikan backup penting sudah disimpan** di tempat lain sebelum menjalankan
- 🔒 **Diperlukan password sudo** untuk pembersihan tingkat sistem

## 🔒 Keamanan & Stabilitas

Script menggunakan `set -euo pipefail` untuk:
- ✅ **Keluar segera** jika ada perintah yang gagal
- ✅ **Keluar jika menggunakan** variabel yang belum didefinisikan  
- ✅ **Status keluar pipeline** berdasarkan perintah terakhir yang gagal
- ✅ **Error handling** yang aman untuk setiap operasi

## 📺 Preview Output

Script akan menampilkan antarmuka yang menarik dengan:

```
╔══════════════════════════════════════════════════════════════╗
║                  🧹 SISTEM PEMBERSIHAN 🧹                    ║
║                     Script Otomatis v2.0                     ║
║                    Optimized for Dark Theme                   ║
╚══════════════════════════════════════════════════════════════╝

🔄 Mempersiapkan sistem pembersihan...
████████████████████████████████████████ 100%

╭─────────────────────────────────────────────────────────────╮
│  ⚙ PEMBERSIHAN TINGKAT SISTEM (membutuhkan sudo)     │
╰─────────────────────────────────────────────────────────────╯

➤ Menghapus paket dependensi yang tidak diperlukan    [ ✓ SUKSES ]
➤ Membersihkan cache paket APT                        [ ✓ SUKSES ]
➤ Membersihkan log journal sistem (menjadi maks 100MB)[ ✓ SUKSES ]
```

### 🎨 **Fitur Visual**
- **Header & Footer** bergaya box art dengan border unicode
- **Progress indicators** real-time dengan animasi
- **Color coding** untuk setiap jenis operasi
- **Status feedback** yang jelas dan mudah dibaca
- **Timestamp** dan informasi direktori backup
- **Startup animation** dengan efek typing yang smooth

## 🚀 Keunggulan v2.0

- 🎨 **UI/UX Modern**: Antarmuka yang jauh lebih menarik
- ⚡ **Performance**: Feedback real-time untuk setiap operasi  
- 🌙 **Dark Theme Optimized**: Warna yang kontras untuk terminal gelap
- 🔄 **Smooth Animations**: Spinner dan progress bar yang halus
- 📊 **Better Feedback**: Status yang lebih informatif dan visual