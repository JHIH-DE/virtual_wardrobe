# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Run the app (env vars required)
flutter run --dart-define-from-file=dart_defines/dev.json

# Build
flutter build apk --dart-define-from-file=dart_defines/dev.json
flutter build ios --dart-define-from-file=dart_defines/dev.json

# Lint
flutter analyze

# Tests
flutter test
flutter test test/widget_test.dart  # single test file
```

`dart_defines/dev.json` is gitignored — copy from `dart_defines/dev.json.template` and fill in `BASE_URL` and `GOOGLE_CLIENT_ID`. The app will not compile without `--dart-define-from-file`.

## Architecture

**Layer structure:**

- `lib/data/` — plain Dart model classes (`Garment`, `Outfit`, `TripPlan`). Each has `fromJson`/`toJson` and uses `copyWith` with `clearX` bool flags for nullable fields.
- `lib/core/services/` — REST API clients. All mix in `BaseService`, which provides `getSafeToken()`, `authHeaders()`, `decodeMap()`, and `throwIfAuthExpired()`. Most services are plain classes instantiated per call. `GarmentService` and `MatchLookService` are singletons via `factory` + `_internal()` because they hold shared mutable state (e.g. `GarmentService`'s in-memory cache) — other services should stay plain classes unless they gain similar shared state.
- `lib/core/providers/` — Riverpod `AsyncNotifierProvider` wrappers over services. Providers expose `refresh()` and optimistic mutation methods (e.g. `addGarment`, `removeGarment`).
- `lib/core/config/` — `Env` reads `String.fromEnvironment` values; `AppConfig` exposes `fullApiUrl`.
- `lib/features/` — screens/pages. Multi-tab pages (`FittingRoomPage`, `OutfitPlannerPage`) use `DefaultTabController`.
- `lib/features/widgets/` — reusable UI components (`PageAppBar`, `AppCard`, `BottomSearchBar`, etc.).
- `lib/app/theme/` — `AppColors`, `AppTextStyles`, `AppTheme` (Material 3). Always use `AppColors` constants instead of inline `Color(...)`.
- `lib/l10n/app_strings.dart` — `AppStrings` static constants for user-facing strings.

## Key Patterns

**API responses** follow a consistent envelope: `{ "data": ... }`. Use `decodeMap(res, op: 'opName')` then cast `envelope['data']`.

**Auth expiry** — services throw `AuthExpiredException` on HTTP 401. Pages that use Riverpod providers listen for this error and call `AuthExpiredHandler.handle(context)`, which clears the token and navigates back to `LoginPage`. Always handle `AuthExpiredException` at the page layer, not inside services.

**Garment image upload** is a three-step flow: `initUpload()` → PUT to signed S3 URL → `completeUpload()`. `analyzeGarment()` uses multipart POST and is called during the add-garment flow to pre-fill metadata.

**Virtual try-on** is an async job. `TryOnMixin` encapsulates job creation, polling every 2 seconds (max 180 attempts), result state, and cleanup. Mix it into any `State<T>` that needs try-on functionality.

**Navigation** is imperative throughout (`Navigator.push` / `MaterialPageRoute`). There is no named-route or go_router setup.

**Riverpod pages** extend `ConsumerStatefulWidget` / `ConsumerWidget`. Use `ref.watch` in `build` and `ref.read` in callbacks. Auth-expiry listeners are set up in `initState` via `WidgetsBinding.instance.addPostFrameCallback`.

**Garment add/edit flow:** `GarmentUploadHelper.showAddClothingDialog` → `CameraCapturePage` or gallery pick → `ImageEditPage` (returns `ImageEditResult`) → `AddGarmentPage` (create or edit). After leaving `AddGarmentPage`, the caller refreshes the garment provider.
