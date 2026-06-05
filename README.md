# Intelligent Document Scanner — Tugas Besar PCD

**Realtime Adaptive Document Digitization using Mobile Computer Vision**

Aplikasi Flutter untuk digitalisasi dokumen secara real-time di perangkat mobile menggunakan teknik **Pengolahan Citra Digital (PCD)** murni berbasis OpenCV, tanpa model machine learning untuk deteksi tepi.

## Fitur

- **Real-time document detection** — deteksi 4 sudut dokumen dari kamera (CLAHE → bilateral → Canny + Sobel-Otsu → contour scoring)
- **Perspective correction** — warp homography ke bird's eye view
- **4 enhancement modes:**
  - `B&W` — shadow removal + adaptive threshold + morph close (terbaik untuk teks)
  - `Grayscale` — shadow removal + CLAHE + bilateral filter
  - `Color` — CLAHE di LAB + unsharp mask
  - `Magic` — Color + saturation boost + gamma (efek CamScanner Magic Color)
- **Auto-capture** — trigger otomatis saat dokumen stabil
- **Dual engine:** PCD (buatan sendiri) atau Google ML Kit Document Scanner
- **OCR** — Google ML Kit text recognition pada hasil scan
- **Export PDF** — dari satu atau banyak halaman
- **Penyimpanan lokal** (Hive) + **online** (MongoDB)
- **Before/after slider** — perbandingan hasil enhancement

## Arsitektur

```
lib/
├── config/              → AppConfig, PCD parameter profiles (A4/Buku/KTP/Auto), colors
├── models/              → ScanResult, DocumentPage, ScanArtifact, CapturePayload, dll
├── controllers/         → ScannerController, AutoCaptureController, IsolateManager
├── services/
│   ├── storage/         → Hive (lokal), MongoDB, PDF export, file service
│   ├── scanner/         → ML Kit document scanner wrapper
│   ├── ocr/             → Text recognition (Google ML Kit)
│   └── image_processing/ → Pipeline PCD utama
├── views/               → Splash, Auth, Home, Scanner, Crop, Processing, History, Profile
├── widgets/             → Scanner overlay, document preview, before/after slider
└── main.dart            → Entry point
```

### Pipeline PCD (`DocumentPipeline`)

1. **Load JPG** → BGR Mat (OpenCV)
2. **Downscale** → long side ≤ 2000 px untuk performa
3. **Edge Detection** — CLAHE lokal → bilateral filter → adaptive Canny (sigma method) + Sobel-Otsu rescue → morphological close → top-5 contour scoring
4. **Perspective Transform** — warp ke koordinat lurus
5. **Quality Assessment** — Laplacian variance (proxy ketajaman)
6. **Enhancement** — sesuai mode yang dipilih

### Scanner Realtime (deteksi frame)

Frame kamera diproses di **Isolate** terpisah agar tidak memblokir UI. Corner points di-smooth dengan **EMA** dan micro-jitter suppression.

## Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter (Dart) |
| Computer Vision | `opencv_dart` (OpenCV 4.x) |
| State Management | Riverpod + ChangeNotifier |
| Concurrency | `flutter_isolate` |
| Local Storage | Hive |
| Online DB | MongoDB (`mongo_dart`) |
| OCR | Google ML Kit (`google_mlkit_text_recognition`) |
| PDF | `pdf` + `printing` |

## Memulai

```bash
flutter pub get
flutter run
```

### Dependencies utama

- `camera: ^0.10.5+2`
- `opencv_dart: ^2.2.1+4`
- `google_mlkit_text_recognition: ^0.13.0`
- `flutter_riverpod: ^2.4.9`
- `hive: ^2.2.3`
- `mongo_dart: ^0.10.3`

## Profil Dokumen

Tuning parameter PCD disesuaikan per jenis dokumen:

| Plan | Canny | Min Area | Gaussian | CLAHE | Adaptive Block | Aspect Ratio |
|---|---|---|---|---|---|---|
| Auto | 50/150 | 8% | 5×5, σ=1.5 | 2.0 / 8×8 | 25 | 1:1.414 |
| A4 | 60/170 | 18% | 5×5, σ=1.4 | 2.0 / 8×8 | 25 | 1:1.414 |
| Buku | 45/140 | 12% | 5×5, σ=1.6 | 2.5 / 8×8 | 31 | 1:1.5 |
| KTP | 70/200 | 5% | 3×3, σ=1.0 | 1.5 / 8×8 | 19 | 85.6:53.98 |

## Lisensi

Proyek ini dibuat untuk tugas besar mata kuliah Pengolahan Citra Digital (PCD).
