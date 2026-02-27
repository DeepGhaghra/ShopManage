---
name: managing-devops-deployment
description: Manages build, release, and deployment workflows for the Sales App Flutter project. Use when the user asks about building the APK or IPA, signing the app, configuring Android/iOS build files, setting up CI/CD, managing app versions, publishing to the Play Store or App Store, or configuring environment-specific Supabase credentials.
---

# DevOps/Deployment Agent — Sales App

## When to use this skill
- User wants to build a release APK or App Bundle
- User asks about app signing, keystores, or provisioning profiles
- User wants to bump the version number
- User asks about Play Store or App Store submission
- User needs to configure different environments (dev/prod Supabase URLs)
- User wants to set up CI/CD (GitHub Actions, Codemagic, Fastlane)
- User asks about build errors related to `android/`, `ios/`, or `pubspec.yaml`

## Project Context
- **App name:** `sales_app`
- **Version:** `1.0.0+1` (in `pubspec.yaml` line 19)
- **Platforms:** Android (primary), iOS, Windows, macOS, Linux, Web
- **Supabase URL:** `https://ltplvmmjgkaxffvwowub.supabase.co` (in `lib/main.dart`)
- **Min SDK:** Check `android/app/build.gradle`
- **Permissions used:** Notifications, exact alarms, storage, network

## Workflow

- [ ] Identify target platform (Android / iOS / Web / Desktop)
- [ ] Confirm version bump if this is a release
- [ ] Verify `pubspec.yaml` dependencies are up to date (`flutter pub outdated`)
- [ ] Run `flutter clean` before building release
- [ ] Build the release artifact
- [ ] Sign with correct keystore / certificates
- [ ] Test on a physical device before submitting

## Instructions

### Version Bumping
In `pubspec.yaml`:
```yaml
version: 1.2.0+5   # format: semver+buildNumber
#         ^   ^
#    versionName  versionCode (Android)
```

### Android Release Build
```bash
# Clean build
flutter clean

# Build APK (single file, sideloading)
flutter build apk --release

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Output locations:
# APK:    build/app/outputs/flutter-apk/app-release.apk
# Bundle: build/app/outputs/bundle/release/app-release.aab
```

### Android Signing — `android/app/build.gradle`
```groovy
android {
  signingConfigs {
    release {
      keyAlias keystoreProperties['keyAlias']
      keyPassword keystoreProperties['keyPassword']
      storeFile file(keystoreProperties['storeFile'])
      storePassword keystoreProperties['storePassword']
    }
  }
  buildTypes {
    release {
      signingConfig signingConfigs.release
    }
  }
}
```
Store `key.properties` in `android/` (never commit to git):
```
storePassword=<password>
keyPassword=<password>
keyAlias=<alias>
storeFile=../keystore.jks
```

### iOS Release Build
```bash
flutter build ipa --release
# Output: build/ios/archive/Runner.xcarchive
```
Then use Xcode Organizer or `xcrun altool` to upload to App Store Connect.

### Environment Configuration (Dev vs. Prod)
Create separate Dart files or use `--dart-define`:
```bash
# Build with custom Supabase URL
flutter build apk --dart-define=SUPABASE_URL=https://your-url.supabase.co \
                  --dart-define=SUPABASE_KEY=your-anon-key
```
In `main.dart`, replace hardcoded values:
```dart
const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
  defaultValue: 'https://ltplvmmjgkaxffvwowub.supabase.co');
const supabaseKey = String.fromEnvironment('SUPABASE_KEY',
  defaultValue: 'your-default-key');
await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
```

### Required Android Permissions (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

### GitHub Actions CI Template
```yaml
name: Flutter CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release
```

### Pre-Release Checklist
- [ ] Version bumped in `pubspec.yaml`
- [ ] `debugShowCheckedModeBanner: false` in `GetMaterialApp` ✅ (already set)
- [ ] Supabase anon key not exposed in public repo (consider `--dart-define`)
- [ ] All `print()` statements removed or replaced with proper logging
- [ ] Tested on Android physical device
- [ ] Notification permissions work on Android 13+
- [ ] Printer setup tested on target network

## Resources
- Version: `pubspec.yaml` line 19
- App entry: `lib/main.dart`
- Android config: `android/app/build.gradle`
- iOS config: `ios/Runner.xcodeproj`
