# SapScanner Flutter

SapScanner is a Flutter document scanner, converter, OCR, and compression app with web and native targets.

## Current Status

The Flutter Android scaffold has been generated and the SapScanner app is now running as a native Flutter codebase with an MVC-style structure:

- `lib/src/models` for scan, export, and compression data models
- `lib/src/controllers` for app state and user actions
- `lib/src/services` for scanning, OCR, exports, file import, and compression
- `lib/src/views` for the mobile UI

The project currently passes:

```powershell
flutter pub get
flutter analyze
flutter test
```

On this PC, Flutter is available from the local SDK at:

```text
C:\flutter\bin\flutter.bat
```

If Flutter is not on your Windows `PATH`, run commands like this from this folder:

```powershell
$env:FLUTTER_SUPPRESS_ANALYTICS="true"
C:\flutter\bin\flutter.bat --no-version-check pub get
```

## Vercel Web Deployment

This repo includes `vercel.json` and `scripts/vercel-build.sh` for Vercel.

Vercel settings:

- Framework Preset: Other
- Build Command: `bash scripts/vercel-build.sh`
- Output Directory: `build/web`

The build script installs Flutter on Vercel, runs `flutter pub get`, and builds the web app with root hosting:

```bash
flutter build web --release --base-href /
```

The Flutter version is pinned to `3.46.0-0.3.pre` to match the local project. You can override it in Vercel with a `FLUTTER_VERSION` environment variable.

## Android Build Notes

`flutter doctor` can see the Android SDK, but this machine still needs Android command-line tools and accepted Android licenses before APK builds are clean.

Install or fix these in Android Studio:

- Android SDK Command-line Tools
- Android SDK Platform Tools
- Android SDK Build Tools
- Android licenses through `flutter doctor --android-licenses`

The current APK build also fails while Java downloads Gradle because the Java certificate store does not trust the Gradle download certificate chain. Fixing the Java/Gradle certificate trust issue, or pre-installing the Gradle distribution, should unblock `flutter build apk --debug`.

## Native Features

- Android document scanner: `google_mlkit_document_scanner`
- iOS document scanner: VisionKit bridge through a custom platform channel
- Camera preview and manual capture: `camera`
- OCR: `google_mlkit_text_recognition`
- Image processing: `image` package plus native platform accelerators later
- PDF generation: `pdf` and `printing`
- File/folder intake: `file_picker`
- Compression archive support: `archive`
- Share/export: `share_plus`

The goal is not to copy CamScanner. The goal is to make SapScanner faster, more private, more local, and more complete for African and international users.
