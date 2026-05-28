# crmx

A Flutter CRM app backed by Firebase (Android, iOS, Web).

## Setup for New Developers

### 1. Firebase

This repo does not include `firebase_options.dart` or `google-services.json` — you need to generate these for your own Firebase project.

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`
3. Run `flutterfire configure` in the project root and follow the prompts
4. This generates `firebase_options.dart` and `android/app/google-services.json` locally (they are gitignored)

### 2. Environment Variables

Copy `.env.example` to `.env` and fill in your keys:

```
cp .env.example .env
```

Get a free AviationStack API key at [aviationstack.com](https://aviationstack.com).

### 3. Running the App

Pass env vars at build time using `--dart-define`:

```
flutter run --dart-define=AVIATIONSTACK_API_KEY=your_key_here
```

For release builds:

```
flutter build apk --dart-define=AVIATIONSTACK_API_KEY=your_key_here
```
