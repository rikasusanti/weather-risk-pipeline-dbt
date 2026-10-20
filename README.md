🌦️ Global Weather Risk Pipeline (dbt + Snowflake)

Pipeline data engineering modular menggunakan dbt (Data Build Tool) dan Snowflake untuk mengolah dan menganalisis data cuaca global dari Pelmorex Weather Source (tersedia gratis di Snowflake Marketplace). Proyek ini membandingkan data observasi cuaca harian terhadap acuan klimatologi (climatology normal) untuk mengidentifikasi anomali cuaca ekstrem (seperti heatwave, hujan lebat, dan angin kencang).

📌 Sumber Data (Snowflake Marketplace - Free)

Data mentah diperoleh dari data share gratis tanpa biaya:

Listing: Global Weather & Climate Data by Pelmorex Weather Source

Database Sumber: WEATHER_SOURCE_RAW

Skema: PWS_BI_SAMPLE

Tabel yang Digunakan:

POINT_HISTORY_DAY (Histori harian pengamatan cuaca)

POINT_CLIMATOLOGY_DAY (Nilai normal rata-rata klimatologi berbasis NOAA)

POINT_FORECAST_DAY (Prakiraan cuaca harian ke depan)

🏗️ Alur Data & DAG (Lineage)

```text
[Marketplace: point_history_day]     ---> [stg_weather_history]     \
                                                                     ---> [int_weather_anomaly_metrics] ---> [fct_global_weather_risk_summary]
[Marketplace: point_climatology_day] ---> [stg_weather_climatology] /
[Marketplace: point_forecast_day]    ---> [stg_weather_forecast]
```

-----------

📂 Struktur Repositori

```text
weather-risk-pipeline-dbt/
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   ├── stg_weather_history.sql
│   │   ├── stg_weather_forecast.sql
│   │   └── stg_weather_climatology.sql
│   ├── intermediate/
│   │   └── int_weather_anomaly_metrics.sql
│   └── marts/
│       └── fct_global_weather_risk_summary.sql
├── orchestration/
│   └── snowflake_tasks_dag.sql
│   └── cek_riwayat_eksekusi.sql
├── dbt_project.yml
├── .gitignore
└── README.md
```

🚀 Panduan & Urutan Cara Menjalankan

```text
Ikuti tahapan berikut secara berurutan untuk menyiapkan lingkungan dan mengeksekusi pipeline:

1. Pertama, membuat database target penyimpanan. Buat database baru yang memiliki izin tulis (write operations) sebagai tempat penyimpanan seluruh tabel dan view hasil transformasi:

USE ROLE ACCOUNTADMIN;
CREATE DATABASE IF NOT EXISTS WEATHER_ANALYTICS_DB;
USE DATABASE WEATHER_ANALYTICS_DB;
USE SCHEMA PUBLIC;

2. Kedua, inisialisasi dbt project di My Workspace

Pada menu kerja (My Workspace / dbt Studio di Snowflake), buat proyek dbt baru dengan nama repositori weather_risk_pipeline_dbt.

3. Ketiga, konfigurasi profiles.yml

Pada berkas profiles.yml, pastikan parameter role, warehouse, database, dan schema yang dipilih sudah sesuai dengan lokasi tujuan tabel int_weather_anomaly_metrics dan fct_global_weather_risk_summary disimpan:

weather_risk_pipeline_dbt:
  target: dev
  outputs:
    dev:
      type: snowflake
      role: ACCOUNTADMIN
      warehouse: COMPUTE_WH
      database: WEATHER_ANALYTICS_DB
      schema: PUBLIC
      threads: 8


4. Keempat, buat 3 folder layer di dalam folder models/

Buat 3 subdirektori berikut di dalam folder models/:

staging/ (View): Berfungsi sebagai penyaring dan penyeragam data mentah tanpa menduplikasi penyimpanan fisik.

intermediate/ (Table): Berfungsi untuk menggabungkan histori cuaca dengan acuan klimatologi guna menghitung metrik anomali suhu.

marts/ (Fact Table): Menghasilkan tabel mart siap pakai (fct_global_weather_risk_summary) untuk kebutuhan visualisasi/dashboard dengan label status hijau Success pada visual lineage DAG.

5. Kelima, jalankan file pada staging, diikuti dengan intermediate dan terakhir marts.
```

### DAG
<img width="1817" height="738" alt="image" src="https://github.com/user-attachments/assets/e9254679-f449-43d8-b9c4-39fa958718e8" />

### My Workspace
<img width="501" height="910" alt="image" src="https://github.com/user-attachments/assets/a31c5f6c-3c5e-4bef-adbb-b767c61b678c" />

### DB Sumber
<img width="492" height="268" alt="image" src="https://github.com/user-attachments/assets/9a2c9329-99c0-4f92-9cf6-c33aad2e6a08" />

### DB Target
<img width="482" height="557" alt="image" src="https://github.com/user-attachments/assets/aafaaa35-9c66-4e8a-a973-fbbae1a8bac8" />


### (Opsional) Otomasi Orkestrasi via Snowflake Task DAG ###

Jalankan kueri pada berkas orchestration/snowflake_tasks_dag.sql untuk menjadwalkan alur eksekusi otomatis secara berkala menggunakan Snowflake Tasks.

## ⚙️ Orkestrasi & Penjadwalan: Snowflake Tasks vs. dbt Cloud

Berkas `orchestration/snowflake_tasks_dag.sql` disediakan untuk mengotomatisasi dan menjadwalkan alur pembaruan data secara berkala (*scheduled job*) menggunakan fitur native **Snowflake Task DAG**.

### Batasan Arsitektur Native Snowflake Tasks
Perintah `CREATE TASK` dieksekusi langsung pada mesin database Snowflake, yang berarti:
* **Tidak Memiliki Kompiler dbt:** Mesin Snowflake tidak dapat menginterpretasikan struktur repositori file dbt maupun sintaks templating Jinja (seperti `{{ ref(...) }}`, `{{ source(...) }}`, atau blok `{{ config(...) }}`).
* **Ketergantungan Objek Terkompilasi:** Snowflake Tasks hanya dapat mengeksekusi objek SQL murni (`VIEW` atau `TABLE`) yang sudah berhasil dibangun sebelumnya melalui proses kompilasi awal (`dbt run` / `dbt build`).

### Alternatif Produksi: dbt Cloud Jobs
Jika seluruh siklus orkestrasi ingin mempertahankan dependensi model dbt, manajemen struktur folder otomatis, serta kapabilitas CI/CD secara penuh, implementasi penjadwalan sebaiknya dialihkan ke **dbt Cloud Jobs**:
* Mengatur *Job Scheduler* terpusat melalui antarmuka dbt Cloud (menggunakan *Trigger Schedule / Cron*).
* Mengeksekusi perintah tunggal `dbt build` yang secara otomatis mengenali seluruh pohon silsilah data (*lineage DAG*) dari layer `staging`, `intermediate`, hingga `marts` tanpa perlu mendefinisikan ulang ketergantungan antartabel secara manual di level database.
