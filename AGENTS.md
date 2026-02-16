# Pocket Cart — Agent Instructions (Codex / AI)

This repo is a Flutter app: **shopping list creator** with offline-first local DB + Firebase sync.

## Non-negotiables
- **Flutter SDK via FVM only** (no system Flutter).
- **State management:** Riverpod with code generation (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`).
- **Data models:** Freezed + `json_serializable` (`freezed_annotation`, `json_annotation`).
- **Local database:** Drift (offline-first, source of truth for UI).
- **Cloud:** Firebase Auth (email/password) + Cloud Firestore (per-user schema).
- **No Retrofit/Dio** in this project.

---

## Flutter SDK via FVM (required)
- Use **FVM** for all Flutter/Dart commands in this repo.
- Flutter version is pinned in `.fvmrc` (do not use system Flutter).
- Run commands with FVM:
    - `fvm flutter pub get`
    - `fvm dart run build_runner build -d`
    - `fvm flutter analyze`
    - `fvm flutter test`
    - `fvm flutter run -d chrome`
- If you must reference the SDK path, use `.fvm/flutter_sdk`.

---

## Routing (typed go_router only)
- Use **typed go_router** with code generation (`go_router_builder`). Do not add untyped `GoRoute(...)` definitions.
- Routes must be `GoRouteData` classes using:
    - `class XRoute extends GoRouteData with $XRoute`
    - `static const String path = ...`
- Router must use generated routes:
    - `GoRouter(routes: $appRoutes, ...)`
- Navigation must be typed only:
    - `const HomeRoute().go(context);`
    - `ListDetailRoute(listId).push(context);`
- When adding new screens, add a typed route class + update the annotated route tree in `lib/app_router.dart`, then regenerate:
    - `fvm dart run build_runner build -d`

---

## Localization (Flutter gen-l10n required)
- All user-facing strings must be localized using **Flutter’s official l10n (gen-l10n)**.
- No hardcoded UI strings in widgets (titles, buttons, hints, snackbars, dialogs, validators, empty states).
- Use `context.l10n`.
- ARB files live in `lib/l10n/`:
    - `app_en.arb` is the template source of truth.
    - Add new keys in English first and include `@key` descriptions.
- Use ICU pluralization for counts and placeholders for dynamic text.
- Ensure MaterialApp(.router) includes:
    - `localizationsDelegates: AppLocalizations.localizationsDelegates`
    - `supportedLocales: AppLocalizations.supportedLocales`
- After changing ARB files, regenerate and verify:
    - `fvm flutter gen-l10n`
    - `fvm flutter analyze`
    - `fvm flutter test`

---

## Architecture & folder conventions
- Feature-first structure:
    - `lib/features/auth/`
    - `lib/features/lists/`
    - `lib/features/settings/`
    - `lib/core/` (database, logging, constants, errors)
- Keep boundaries clear:
    - UI (presentation) → controllers/notifiers → repositories → datasources (local/remote)
- Avoid “god classes”. Prefer small, focused files.

---

## Drift + offline-first rules
- Drift is the **source of truth** for UI and business logic.
- No hard deletes: use tombstones:
    - `isDeleted=true` and `deletedAt` set.
- Maintain `createdAt` and `updatedAt` for lists/items.
- Manual ordering:
    - items use `sortOrder` (int); reordering updates `sortOrder`.
- Search should be performed **locally** (Drift), not via Firestore.

---

## Firebase + sync rules
- Per-user Firestore schema:
    - `users/{uid}/lists/{listId}`
    - `users/{uid}/lists/{listId}/items/{itemId}`
- Sync strategy:
    - Local-first with an **outbox queue** for user-initiated changes.
    - Remote changes applied locally must NOT enqueue outbox events (avoid echo loops).
    - Conflict strategy: **last-write-wins** using `updatedAt`.

---

## Code generation workflow
- Generators used:
    - `riverpod_generator`
    - `freezed`
    - `json_serializable`
    - `drift_dev`
    - `go_router_builder`
- After changing annotated files, models, routes, or Drift schema, run:
    - `fvm dart run build_runner build -d`

---

## Testing & quality gate
- Minimum: unit tests for repositories/DAOs and sync conflict logic.
- Preferred: at least one widget test per major flow.
- Before finishing a task, run:
    - `fvm flutter pub get`
    - `fvm dart run build_runner build -d`
    - `fvm flutter analyze`
    - `fvm flutter test`

---

## Git workflow
- Make incremental commits with clear messages (Conventional Commits preferred).
- Summarize changes and list the exact commands to verify after modifications.
