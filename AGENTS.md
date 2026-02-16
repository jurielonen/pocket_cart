# Project: Shopping List (Flutter + Firebase + Drift)

## Flutter SDK via FVM (required)
- Use **FVM** for all Flutter/Dart commands in this repo.
- The Flutter version is pinned in `.fvmrc` (do not use system Flutter).
- Always run commands with FVM:
    - `fvm flutter pub get`
    - `fvm dart run build_runner build -d`
    - `fvm flutter analyze`
    - `fvm flutter test`
    - `fvm flutter run -d chrome`
- If you must reference the SDK path (rare), use `.fvm/flutter_sdk`.

## Non-negotiables
- Use Drift for local DB (offline-first).
- Use Riverpod with code generation.
- Use Freezed + json_serializable for data models.
- Firebase Auth (email/password) + Cloud Firestore per-user.
- No Retrofit/Dio in this project.

## Coding conventions
- Feature-first structure: features/auth, features/lists, features/settings
- Repository pattern; data sources: local (drift) + remote (firestore)
- Prefer small files, clear naming, no god classes
- Must compile on Android/iOS/Web
- Use fvm

## Workflow
- Run: fvm flutter pub get, fvm dart run build_runner build -d, fvm flutter analyze, fvm flutter test
- Explain decisions briefly in PR-style notes.
