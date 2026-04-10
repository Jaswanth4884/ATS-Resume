# Firebase Setup For Email Verification

This project is already wired for Firebase Auth email verification in code.

## 1) Create Firebase project
- Go to Firebase Console and create/select a project.
- Enable Authentication -> Sign-in method -> Email/Password.

## 2) Register app IDs
- Android package name should match `android/app/build.gradle.kts` `applicationId`.
- iOS bundle ID should match Xcode Runner bundle identifier.

## 3) Add platform config files
- Android: place `google-services.json` at `android/app/google-services.json`.
- iOS: place `GoogleService-Info.plist` in `ios/Runner/GoogleService-Info.plist`.

## 4) Install Firebase CLI tools (recommended)
- `dart pub global activate flutterfire_cli`
- `flutterfire configure`

This command can also generate `lib/firebase_options.dart` for multi-platform setup.

## 5) Rebuild app
- `flutter clean`
- `flutter pub get`
- `flutter run`

## 6) How verification works now
- On register, app creates Firebase user and sends verification email.
- User opens email and clicks verification link.
- In app, user taps Verify button on the verification screen.
- Login is allowed only after `emailVerified == true`.

## Notes
- Firebase Auth sends verification links, not 6-digit OTP by default.
- If you need numeric OTP by email, use Firebase Cloud Functions + email provider.
