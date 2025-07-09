## í ½í³¦ Mengetahui Kapasitas Disk di Docker Container

### í ½í´¹ 1. Melihat Disk Usage dari Dalam Container

```bash
docker exec -it <nama_container> bash
# atau jika shell-nya sh
docker exec -it <nama_container> sh
```

Lalu di dalam container:

```bash
df -h
```

**Keterangan:**
- `df -h` menunjukkan penggunaan disk dalam format yang mudah dibaca (human-readable).
- Kolom `overlay` mewakili root filesystem container.
- `Size`, `Used`, dan `Avail` menunjukkan total, terpakai, dan sisa disk yang bisa digunakan container.

---

### í ½í´¹ 2. Melihat Pemakaian Storage oleh Docker Engine (Global)

```bash
docker system df
```

**Keterangan:**
- Menampilkan ringkasan penggunaan disk oleh images, containers, volumes, dan cache secara global.

Untuk versi lebih rinci:

```bash
docker system df -v
```

---

### í ½í´¹ 3. Melihat Detail Volume Tertentu

```bash
docker volume inspect <nama_volume>
```

**Keterangan:**
- Menampilkan informasi volume termasuk `Mountpoint` di host system.

Untuk melihat ukuran data di dalam volume (dari host):

```bash
sudo du -sh /var/lib/docker/volumes/<nama_volume>/_data
```

**Keterangan:**
- `du -sh` menampilkan ukuran folder volume secara ringkas (`-s`) dan dalam satuan yang mudah dibaca (`-h`).

---

## í ½í»  Tips Tambahan

- Gunakan tools seperti **cAdvisor**, **Grafana + Prometheus**, atau **Docker Desktop dashboard** untuk monitoring otomatis dan visual.
- Jika container menggunakan **bind mount**, cek disk usage langsung di direktori host yang dimount ke container.
