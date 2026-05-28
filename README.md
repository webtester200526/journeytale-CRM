# JourneyTale

Aplikasi CRM Flutter yang didukung oleh Firebase (Android, iOS, Web).

## Setup 

### 1. Firebase

Repo ini tidak menyertakan `firebase_options.dart` atau `google-services.json` — Anda perlu membuat file tersebut untuk project Firebase Anda sendiri.

1. Buat project Firebase baru di `console.firebase.google.com`
2. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. Jalankan `flutterfire configure` di root project dan ikuti instruksinya
4. Perintah tersebut akan menghasilkan `firebase_options.dart` dan `android/app/google-services.json` secara lokal (file tersebut sudah masuk `.gitignore`)

### 2. Environment Variables

Salin `.env.example` menjadi `.env` lalu isi API key Anda:

```bash
cp .env.example .env
```

Dapatkan AviationStack API key gratis di `aviationstack.com`.

### 3. Menjalankan Aplikasi

Pass environment variables saat build menggunakan `--dart-define`:

```bash
flutter run --dart-define=AVIATIONSTACK_API_KEY=your_key_here
```

Untuk release build:

```bash
flutter build apk --dart-define=AVIATIONSTACK_API_KEY=your_key_here
```
