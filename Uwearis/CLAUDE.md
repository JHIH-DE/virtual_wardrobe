# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It is the **binding engineering standard** for this project — new code and refactors must follow it. If a rule here conflicts with existing code that hasn't been migrated yet, the rule wins for new code; migrating old code to match is tracked separately (see the project's consistency-refactor plan), not silently done as a side effect of unrelated work.

Several rules below distinguish **current state** (what the codebase actually looks like right now, evidence-checked), **target pattern** (what new or substantively-touched code must follow), and **migration debt** (existing code that doesn't yet match the target — not to be mass-migrated as a side effect of unrelated work). Where a rule doesn't make this distinction explicitly, it's because current state and target already match.

## Language

Respond to the user in Traditional Chinese (繁體中文). Code, identifiers, and commit messages stay in English as usual.

## Related repository

This is the Flutter frontend ("Uwearis" / "virtual wardrobe"). The FastAPI backend lives in a separate sibling repository (`virtual-wardrobe-backend` — ask for its local path if it isn't already known in this environment), which has its own `CLAUDE.md`. That document is the sole source of truth for backend architecture, layering, naming, and feature behavior — this file does not duplicate it. Read it before working on any backend code. When the two disagree on anything backend-related, the backend repo's own `CLAUDE.md` wins; this file only governs the Flutter code below and the [Shared contract](#shared-contract-both-stacks) section at the end.

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
flutter test test/services/garment_service_test.dart   # single test file
```

`dart_defines/dev.json` is gitignored — copy from `dart_defines/dev.json.template` and fill in `BASE_URL` and `GOOGLE_CLIENT_ID`. The app will not compile without `--dart-define-from-file`.

---

# Flutter Frontend Rules

## Architecture

**Layer structure:**

- `lib/data/` — plain Dart model classes (`Garment`, `Outfit`, `Trip`, ...). Each has `fromJson`/`toJson`; models with nullable fields that are genuinely mutated in place also get `copyWith` with `clearX` bool flags (see [Data models](#data-models) below — not every model needs this).
- `lib/core/services/` — REST API clients. All mix in `BaseService`, which provides `getSafeToken()`, `authHeaders()`, `decodeMap()`, `throwIfAuthExpired()`, and `withAuth()`. Most services are plain classes instantiated per call. `GarmentService` is the sole singleton (via `factory` + `_internal()`) because it holds shared mutable state (an in-memory cache) — do not make a new service singleton unless it holds equivalent shared state.
- `lib/core/providers/` — Riverpod `AsyncNotifierProvider` wrappers over services. Providers expose `refresh()` and verb+noun mutation methods (`addGarment`, `removeGarment` — see [Naming](#naming-conventions)).
- `lib/core/config/` — `Env` reads `String.fromEnvironment` values; `AppConfig` exposes `fullApiUrl`.
- `lib/core/utils/` — cross-cutting helpers: `debug_log.dart` (logging), `signed_url.dart` (GCS signed-URL expiry), `crash_handler.dart`, `route_observer.dart`, `image_cache_bust.dart`, `try_on_mixin.dart`.
- `lib/app/` — app shell. `main_shell.dart` hosts `MainShell`, the persistent 4-tab (`Home`/`My Closet`/`Outfits`/`Trips`) `IndexedStack` shell — see [Navigation](#navigation). `lib/app/theme/` has `AppColors`, `AppTextStyle`, `AppDimens`, `AppTheme` (Material 3).
- `lib/features/pages/` — one file per screen, `ConsumerStatefulWidget`/`StatefulWidget` (Riverpod only where a provider is actually used).
- `lib/features/widgets/` — reusable UI components, organized `common/{buttons,cards,fields,images,overlays}` plus per-domain `garment/`, `outfit/`, `trip/`.
- `lib/l10n/` — ARB source files (`app_en.arb`, ...); `flutter gen-l10n` generates `lib/l10n/generated/app_localizations.dart` (`AppLocalizations`). There is no `AppStrings` class — all user-facing strings go through ARB.

**Navigation**: imperative throughout (`Navigator.push`/`MaterialPageRoute`). No named-route or go_router setup. The 4 main tabs are never pushed as routes — `MainShell` (`lib/app/main_shell.dart`) keeps them alive in one `IndexedStack` and swaps the visible index via `setState`, so switching tabs preserves scroll position/filters and never re-runs `initState`. `MainShellScope` (`lib/features/widgets/common/floating_nav_bar.dart`) is an `InheritedWidget` exposing `selectTab`/`setLoading` down to any descendant — a main-tab page calls `MainShellScope.of(context).setLoading(true, tab: AppTab.home)` instead of showing its own loading overlay (see [Loading/empty/error state](#loadingemptyerror-state)). `FloatingNavBar` (same file) is built once by `MainShell`, not per-page.

**Virtual try-on**: `generate`/`regenerate` on the backend's `OutfitGroup`/`Outfit` API are synchronous — the AI render finishes before the HTTP call returns. `TryOnMixin` (`lib/core/utils/try_on_mixin.dart`) reflects this: a single `await OutfitService().generateOutfit(...)`, no polling, no `Timer`/`Completer`. `TripService.generateOptionOutfit`/`regenerateOptionOutfit` is a second, separate try-on path (used from Trip Plans) that follows the same synchronous single-call shape — don't reintroduce polling in either path; there is no async job/queue on the backend to poll. Note: `Outfit.status`/`Outfit.errorMessage` (`lib/data/outfit.dart`) are parsed from and serialized to JSON but not currently read anywhere in `lib/` — they're a harmless leftover from an earlier job-based design, not something to build new logic on.

**Garment image upload**: three-step flow — `initUpload()` → PUT to signed GCS URL → `completeUpload()`. `analyzeGarment()` is a separate multipart POST called during the add-garment flow to pre-fill metadata (category, color, style, versatility score).

**Auth expiry** — see [Error handling (UI)](#error-handling-ui) below for the full request-to-recovery flow and the current/target distinction for how pages should catch it.

## Naming conventions

- **Files**: `snake_case.dart`, matching the primary class inside (`garment_service.dart` → `GarmentService`).
- **Service classes**: `XxxService`. Define `static final String _baseUrl = '${AppConfig.fullApiUrl}/segment';` at the top and build every endpoint URL off it — never inline a URL string in a method body.
- **Provider classes**: `XxxNotifier` + `xxxProvider` (the `AsyncNotifierProvider` instance).
- **Data model classes**: bare noun (`Garment`, `Outfit`), no suffix.
- **Page classes**: `XxxPage`, State class `_XxxPageState`.
- **Private State fields**: always `_`-prefixed, no exceptions (`_uploading`, `_errorMessage` — not `uploading`, `errorMessage`).
- **Build-helper methods**: `_buildXxx()`, ordered in the file as field declarations → `initState` → `build` → helpers (top to bottom, roughly matching call order from `build`).
- **Dialogs**: `_showXxxDialog()` — a rename action is `_showRenameDialog`, not `_showEditNameDialog`; name dialog methods after the user-facing verb (matches the l10n string), not "edit"-as-generic-verb.
- **Provider mutation methods**: verb + noun, never a bare verb — `addGarment`/`updateGarment`/`removeGarment`, not `add`/`update`/`remove`. This matters because these are called from other files, several layers away from the provider's own import; the noun disambiguates at the call site. (Every provider follows this now — `trips_provider.dart` and `outfits_provider.dart` were migrated to `addTrip`/`removeTrip`/`addOutfit`/… in the page-layer consistency slice.)
- **Debug logging**: see [Logging](#logging) below.
- **Categorical API values**: any fixed vocabulary of string values coming from the API (e.g. an outfit group's `type`) gets a Dart enum with `apiValue`/`fromApiValue(String)`, matching `GarmentCategory`/`StyleType`/`OccasionType`/`TripActivity`/`MatchALookRole`/`OutfitGroupType`. Never compare a raw string literal against an API field.
- **Cache keys / repeated literal strings**: if the same string template is built in more than one place (e.g. an outfit's image cache key), extract one small helper/constant next to the model it belongs to — don't let each call site re-derive it.

## Service layer rules

- **Singleton policy**: plain class by default. Only use `factory` + `_internal()` when the service holds real shared mutable state (an in-memory cache, a live connection) — not for DI convenience, not "for consistency." `GarmentService` is the only service that qualifies.
- **HTTP errors**: never hand-build an error message string outside `BaseService.decodeMap`. If a status code needs special handling (e.g. treat 404 as success for an idempotent delete), check `res.statusCode` *before* calling `decodeMap`, don't catch and reformat its exception. Idempotent `DELETE`s go through `BaseService.deleteIdempotent` (404/2xx = success, everything else routed through `decodeMap` or a passed-in `errorDecode` so the message is still built in one place) rather than each service re-rolling the branch — `GarmentService.deleteGarment` and `MatchLookService.removeReference` both use it.
- **JSON numeric parsing**: always `(json['x'] as num?)?.toDouble()` / `.toInt()` — never a raw `as int?`/`as double?` cast on a field that comes from an external API. APIs can serialize the same field as an int or a float depending on the value; a raw cast crashes the first time it doesn't match.
- **Signed URLs**: use `lib/core/utils/signed_url.dart`'s expiry helper rather than re-deriving "is this URL stale" inline at each call site.

## Provider layer rules

- `ref.watch` in `build`, `ref.read` in callbacks — no exceptions.
- `refresh()` follows the standard `AsyncNotifier` shape: `state = const AsyncLoading(); state = await AsyncValue.guard(...)`. This is idiomatic Riverpod and is expected to look the same in every provider — don't extract a shared base class for it.
- Mutation methods use the verb+noun naming from [Naming conventions](#naming-conventions) above.

## Data models

- `fromJson` parses every numeric field defensively (see [Service layer rules](#service-layer-rules)); prefer a small local parsing closure or inline cast, whichever the file already uses — don't introduce a third idiom into a file that has one.
- Add `copyWith` with `clearX` bool flags for nullable fields **only when the app actually mutates that model's fields in place** (matches `Garment`, `Outfit`). A model that's only ever read, never locally patched, doesn't need one — don't add `copyWith` speculatively.

## UI / page rules

### Loading/empty/error state

- **Main-tab pages** (`HomePage`, `ClosetPage`, `OutfitsPage`, `TripsPage`): route a tab-scoped fetch's loading state through `MainShellScope.of(context).setLoading(...)` — the shell paints one overlay above the nav bar. A cross-tab shared action helper that doesn't know which tab it's running under (e.g. `trips_page.dart`'s `handleCreateTrip`/`handleDeleteTrip`, called from both Home and Trips, or `main_shell.dart`'s own `_openAddOutfit`) may use a modal `LoadingOverlay` dialog instead, since `setLoading` is keyed per-`AppTab`. Outside of that carve-out, don't build a page-local loading overlay on a main tab.
- **Pushed pages**: `Stack` with `Positioned.fill(child: LoadingOverlay(...))`, conditionally shown.
- **Brief in-place fetches**: `AppSpinner`.
- **Empty lists**: `EmptyStatePlaceholder` — never hand-roll an empty-state `Text`.
- **Provider `.when()` error branches**: `ErrorStateWidget`.

### Error handling (UI) {#error-handling-ui}

**Actual request-to-recovery flow.** A `BaseService`-mixed-in call that gets HTTP 401 does not throw immediately:

```
HTTP 401
  → BaseService.withAuth: silent token refresh + retry the original request once
  → refresh/retry still fails (no stored refresh token, refresh call itself fails, or the retry 401s again)
  → AuthExpiredException thrown
  → caught at the page layer
  → AuthExpiredHandler.handle(context)
  → static _isHandling flag dedupes concurrent triggers (e.g. several tabs' listeners firing at once)
```

So "`AuthExpiredException` on 401" really means *unrecoverable* 401 — most transient 401s never reach a page's `catch` at all because `withAuth` already recovered from them.

**Target pattern — required for new code and any method being substantively touched:**

```dart
try {
  ...
} on AuthExpiredException {
  if (!mounted) return;
  await AuthExpiredHandler.handle(context);
  return;
} catch (e) {
  debugLog('...: $e');
  // user-facing fallback (SnackBar / inline error state)
} finally {
  // reset in-flight flags
}
```

`on AuthExpiredException` is its own clause, checked before the generic `catch`. Every network call has a `catch` regardless of which shape is used — a bare `try { ... } finally { ... }` around a network call is a bug, not a style choice, in both the current and target patterns.

**Current state.** Every page/feature-layer call site now uses the target `on AuthExpiredException` shape — the old `if (e is AuthExpiredException)` shared-`catch` shape has been fully migrated out. The one remaining `if (e is AuthExpiredException)` in `lib/` is in `BaseService.withAuth` itself (`e is AuthExpiredException ? rethrow : throw AuthExpiredException()`), which is a deliberate rethrow-guard while *converting* other failures, not the page-layer handle-vs-fallback shape — leave it. Don't reintroduce the `if (e is ...)` shape in new code (it's in [Forbidden patterns](#forbidden-patterns-flutter)).

### `BottomActionButton`

Every page with a bottom action button follows this exact shape (see `image_editor_page.dart`, `garment_details_page.dart`, `account_page.dart`):

```dart
Scaffold(
  extendBody: true,
  bottomNavigationBar: _buildActionButton(), // returns BottomActionButton
  body: Column(
    children: [
      ...,
      SizedBox(height: _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 0),
    ],
  ),
)

bool get _showsBottomActionButton => /* same condition that controls the button's own visibility/enabled state */;
```

Never place `BottomActionButton` inline inside the scrollable body as a sibling widget — it must go through `Scaffold.bottomNavigationBar`. All current call sites in the app follow this shape.

### Section headers and field labels

- A card/section title is `SectionTitle` (bold16, normal case). A field label above a form input is `FieldLabel` (small-caps). Never hand-build `Text(title, style: AppTextStyle.bold18)` as a substitute for `SectionTitle`.
- If two pages need the same card chrome (border, padding, shadow), it's a shared widget in `lib/features/widgets/common/cards/`, not two private `_buildCardShell` copies.

### Localization

- Every page defines `AppLocalizations get _l10n => AppLocalizations.of(context);` and uses `_l10n.xxx` throughout — never call `AppLocalizations.of(context).xxx` inline more than once in the same file.
- No hardcoded `Text('...')` literals for user-facing copy. Every string, including nouns interpolated into a template string (`_l10n.selectItemTitle('Accessory')`), goes through ARB.

### Design tokens

- Never `Color(0x...)` — always `AppColors.*`.
- Never a raw pixel literal that duplicates an existing `AppDimens` constant (`16`/`12` for spacing, `EdgeInsets.fromLTRB(16, 16, 16, 24)` for page grid padding — use `AppDimens.sectionSpacing`/`AppDimens.cardSpacing`/`AppDimens.pageGridPadding`). If a new spacing/radius value is genuinely needed in more than one place, add it to `AppDimens` rather than repeating the literal.
- `BorderRadius.circular(AppDimens.cardRadius)` for cards — check `AppDimens` before writing a raw `circular(N)`; only use a raw literal when the value is deliberately different from every existing token.

## Logging

- Every public service method that performs an HTTP call opens with `debugLog('--- methodName: relevant params ---');`, placed *after* any early-return cache check or parameter resolution needed to make the logged values meaningful — e.g. `GarmentService.getGarment` logs only once it's past its cache-hit fast path, and `OutfitService.generateOutfit` resolves `groupId` before logging so the line carries a real value, not `null`. `base_service.dart`'s internal helpers (`decodeMap`, `withAuth`) do not log directly — logging responsibility stays with the calling method so nothing double-logs. Methods that don't perform an HTTP call (pure getters, trivial wrappers) aren't required to log.
- **Never log**: access tokens, `Authorization` header values, signed URLs, photo/image bytes or data URIs, email addresses, or any other personally-identifying data. A log line naming *which* garment/outfit/trip id was involved is fine; logging the credential or the payload that proves who the user is, is not.

## Canonical example files (Flutter)

Each file below is canonical **only for the specific things listed** — it is not a "copy the whole file" template, and known violations elsewhere in the same file are called out so they aren't copied along with the good parts.

| Category | File | Demonstrates | Known violations — do not copy these parts |
|---|---|---|---|
| Service | `lib/core/services/trip_service.dart` | `_baseUrl` convention, `debugLog`-per-method convention, `decodeMap`-based error handling | Log line format omits the colon separator (`'--- updateTrip id=$tripId ---'`) — follow the written [Logging](#logging) rule's format, not this file's literal string shape |
| Service (singleton) | `lib/core/services/garment_service.dart` | Cache-backed singleton shape, `.timeout()` on every call, cache kept coherent after a successful mutation, `deleteIdempotent`-based delete | — |
| Service (minimal shape) | `lib/core/services/daily_outfit_service.dart` | Minimal stateless (non-singleton) service shape | — |
| Provider | `lib/core/providers/garments_provider.dart` | `AsyncNotifier` `refresh()` shape, verb+noun mutation naming | — (`trips_provider.dart`/`outfits_provider.dart` don't fully mirror this file's naming yet — see [Naming conventions](#naming-conventions)) |
| Data model | `lib/data/outfit.dart` | `copyWith` `clearX` flags, extracted cache-key helper (`outfitImageCacheKey`), `num`-tolerant `parseId`, `OutfitGroupType` enum with `apiValue`/`fromApiValue` | — |
| Page | `lib/features/pages/outfit_details_page.dart` | Field→`initState`→`build`→helper ordering, `_l10n` alias getter, `BottomActionButton` wiring, pushed-page `Positioned.fill(LoadingOverlay)` loading, `on AuthExpiredException` clause shape | one raw `BorderRadius.circular(16)` instead of `AppDimens.cardRadius` |
| Shared widget | `lib/features/widgets/common/buttons/bottom_action_button.dart` | Full compliance — colors via `AppColors`, no hardcoded text, documented literals | — |

When adding a new page/service/provider/model, start from the primary example above for the property you need and follow its shape for that property — don't assume the rest of the file is equally clean.

## Forbidden patterns (Flutter)

- Raw `Color(0x...)` instead of `AppColors`.
- A hardcoded `Text('...')` for user-facing copy instead of `_l10n.xxx`.
- Hand-rolled empty/error state widgets when `EmptyStatePlaceholder`/`ErrorStateWidget` exist.
- `try { ... } finally { ... }` around a network call with no `catch`.
- A service building its own HTTP-error message string instead of going through `BaseService.decodeMap`.
- A raw `as int?`/`as double?` cast on a JSON field sourced from an external API.
- A bare provider mutation-method verb (`add`/`remove`) instead of verb+noun (`addGarment`/`removeGarment`) in new code.
- Copy-pasting a private helper method (`_buildXxx`, a filter-option list, a dialog builder) into a second file instead of extracting a shared widget/constant once it's needed in 2+ places.
- A new abstraction layer, base class, or wrapper introduced for something used in exactly one place "for future flexibility."
- `BottomActionButton` placed inline in the body instead of via `Scaffold.bottomNavigationBar`.
- Logging an access token, `Authorization` header, signed URL, image payload, email, or other personal data (see [Logging](#logging)).
- The `if (e is AuthExpiredException)` shared-catch shape (use the `on AuthExpiredException` clause instead — see [Error handling (UI)](#error-handling-ui)). The codebase is fully migrated to the clause shape apart from `BaseService.withAuth`'s own rethrow-guard.

## Pre-change / post-change checks (Flutter)

Before committing any change under `lib/` or `test/`:

1. `flutter analyze` — zero issues.
2. `flutter test` — all passing; if you touched a service or data model with existing coverage in `test/services/` or `test/data/`, its tests must still pass, and a behavior change needs a matching test update, not just a passing run.
3. If you touched a page's visual layout, loading state, or navigation flow, manually run the app (`flutter run --dart-define-from-file=dart_defines/dev.json`) and exercise the changed screen — `test/` currently has zero coverage for `lib/core/providers/` and `lib/features/`, so analyzer + unit tests alone do not catch a UI regression.
4. A rename of a public method/class (service, provider, or otherwise) requires grepping the whole `lib/`/`test/` tree for the old name before considering the change done.

---

# Shared contract (both stacks)

- **Response envelope**: the backend's `BaseResponse[T]` (`success`, `message`, `data`, `error_code`) is the response shape every Flutter service call receives. In practice, `BaseService.decodeMap` itself only validates HTTP status and that the body is a JSON object — it doesn't parse any of the four keys itself; each service destructures `envelope['data']` by hand after calling it. `data` is load-bearing at essentially every call site (renaming or removing it is a breaking change across the whole app); `error_code`/`message` are currently only consumed by `MatchLookService`'s own decode path; `success` is not currently read anywhere in `lib/`. **`success` being unread today does not make it safe to remove from the backend response shape** — it's still part of the documented contract, and Flutter simply hasn't needed to branch on it yet. Do not change the envelope shape from either side without coordinating both repos in the same change.
- **Auth expiry**: backend unrecoverable 401 → Flutter's `AuthExpiredException` — see [Error handling (UI)](#error-handling-ui) above for the full flow, including the silent-refresh-and-retry step that happens first. Any backend change to when/how 401 is returned must be checked against this mapping.
- **Error codes**: the backend's `ErrorCode` enum is the intended full taxonomy; Flutter does not re-declare it — if a page needs to branch on a specific `error_code`, read the value directly rather than inventing a parallel Dart enum that can drift out of sync. Note the backend's own 500 catch-all currently emits a literal `"INTERNAL_SERVER_ERROR"` that isn't itself an `ErrorCode` member — treat that one value as a special case if you ever need to match it from Flutter, not proof the enum is incomplete elsewhere.
