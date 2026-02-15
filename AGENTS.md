# Project: Shopping List (Flutter + Firebase + Drift)

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

## Workflow
- Before big changes: create a git commit.
- Run: flutter pub get, build_runner, flutter test
- Explain decisions briefly in PR-style notes.
