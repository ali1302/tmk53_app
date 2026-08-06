# TMK Kuwait Flutter App

Mobile/desktop Flutter client for the TMK Kuwait CodeIgniter website.

## Project location

`d:\TMK Kuwait\tmk_kuwait`

## What is already set up

- Flutter SDK `3.44.7` (stable) at `C:\flutter`
- Dart `3.12.2`
- Git, Chrome, Visual Studio Build Tools
- Flutter project with:
  - Login screen
  - Auth provider (JWT token storage)
  - API client pointed at existing `api/v1` endpoints
  - App theme using TMK brand color `#7F1700`

## Run now (without Android)

You can already run on Windows desktop or Chrome:

```powershell
cd "d:\TMK Kuwait\tmk_kuwait"
flutter pub get
flutter run -d windows
# or
flutter run -d chrome
```

## Android setup (required for phone/emulator)

1. Android Studio is installed at `C:\Program Files\Android\Android Studio`.
2. **Enable Windows Developer Mode** (needed for Flutter plugin symlinks):
   - Open Settings → System → For developers → turn on **Developer Mode**
   - Or run: `start ms-settings:developers`
3. Open **Android Studio** once and finish the setup wizard (install Android SDK + platform tools).
4. Optionally create an Android Virtual Device (emulator).
5. Accept licenses:

```powershell
flutter doctor --android-licenses
```

6. Point Flutter at the SDK if needed:

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor -v
```

## API configuration

Edit `lib/core/config/app_config.dart`:

- Local: `http://localhost:7070`
- Live: `https://tmk53.com`
- Android emulator local access: use `http://10.0.2.2:7070`
- Physical phone on same Wi-Fi: use your PC LAN IP, e.g. `http://192.168.x.x:7070`

Existing backend login endpoint used by the app:

`POST /api/v1/auth/login` with `username` + `password`

## Suggested next steps

1. Complete Android Studio + SDK install
2. Confirm `flutter doctor` is clean for Android
3. Decide first feature module (likely Tameer Followup)
4. Add dedicated mobile API endpoints if needed (portal/member flows)
