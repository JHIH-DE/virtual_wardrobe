# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It is the **binding engineering standard** for this project — new code and refactors must follow it. If a rule here conflicts with existing code that hasn't been migrated yet, the rule wins for new code; migrating old code to match is tracked separately (see [Migration debt register](#migration-debt-register-flutter) below), not silently done as a side effect of unrelated work.

Several rules below distinguish **current state** (what the codebase actually looks like right now, evidence-checked), **target pattern** (what new or substantively-touched code must follow), and **migration debt** (existing code that doesn't yet match the target — not to be mass-migrated as a side effect of unrelated work). Where a rule doesn't make this distinction explicitly, it's because current state and target already match.

## Meaning of substantively touched

A file is **substantively touched** when the current task changes its behaviour, data flow, provider/service interaction, state handling, navigation, or visible layout. A comment edit, typo fix, import cleanup, generated-code update, mechanical rename, or unrelated one-line correction does not trigger a full migration of every debt item in that file.

When a trigger fires, fix the relevant local debt that can be safely verified within the same task. Do not turn a small feature or bug fix into an unbounded file-wide rewrite. Widget reuse is the exception to this narrow-scope rule: before adding a new visual component, always perform the reuse search in [Widget reuse and extraction](#widget-reuse-and-extraction), because creating another near-duplicate makes the codebase permanently harder to converge.

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

`dart_defines/dev.json` is gitignored — copy from `dart_defines/dev.json.template` and fill in the Google OAuth client ids. The backend URL is **not** in the JSON: it lives as `Env.baseUrl`'s `defaultValue` (`lib/core/config/env.dart`), the single source of truth — override per-build with `--dart-define=BASE_URL=…` if needed. `flutter test` runs without `--dart-define-from-file`, so the service tests rely on that `defaultValue`.

---

# Flutter Frontend Rules

## Architecture

**Layer structure:**

- `lib/data/` — plain Dart model classes (`Garment`, `Outfit`, `Trip`, ...). Each has `fromJson`/`toJson`; models with nullable fields that are genuinely mutated in place also get `copyWith` with `clearX` bool flags (see [Data models](#data-models) below — not every model needs this).
- `lib/core/services/` — REST API clients. All mix in `BaseService`, which provides `getSafeToken()`, `authHeaders()`, `decodeMap()`, `throwIfAuthExpired()`, and `withAuth()`. Most services are plain classes instantiated per call. `GarmentService` and `OutfitService` are the current cache-backed singletons (via `factory` + `_internal()`); do not make another service singleton unless it holds equivalent shared mutable state.
- `lib/core/providers/` — Riverpod providers over services. Stateful collections/profiles use `AsyncNotifierProvider`; a few parameterized reads use `FutureProvider.family`. Network-backed future providers must use the shared `appRetryPolicy` (see [Async provider retry policy](#async-provider-retry-policy)). Providers expose `refresh()` and verb+noun mutation methods (`addGarment`, `removeGarment` — see [Naming](#naming-conventions)).
- `lib/core/config/` — `Env` reads `String.fromEnvironment` values; `AppConfig` exposes `fullApiUrl`.
- `lib/core/utils/` — cross-cutting helpers: `debug_log.dart` (logging), `signed_url.dart` (GCS signed-URL expiry), `crash_handler.dart`, `route_observer.dart`, `image_cache_bust.dart`, `try_on_mixin.dart`.
- `lib/app/` — app shell. `main_shell.dart` hosts `MainShell`, the persistent 4-tab (`Home`/`My Closet`/`Outfits`/`Trips`) `IndexedStack` shell — see [Navigation](#navigation). `lib/app/theme/` has `AppColors`, `AppTextStyle`, `AppDimens`, `AppTheme` (Material 3).
- `lib/features/pages/` — one file per screen. A page owns route arguments, provider/service coordination, navigation, screen-level loading/error handling, and composition of the screen's major sections. It should not reimplement reusable visual objects that already exist under `lib/features/widgets/`.
- `lib/features/widgets/` — reusable UI components, organized `common/{buttons,cards,fields,images,overlays}` plus per-domain `garment/`, `outfit/`, `trip/`. Similar UI objects across pages must converge on one canonical Widget whenever they represent the same product concept and behaviour; see [Widget reuse and extraction](#widget-reuse-and-extraction).
- `lib/l10n/` — ARB source files (`app_en.arb`, ...); `flutter gen-l10n` generates `lib/l10n/generated/app_localizations.dart` (`AppLocalizations`). There is no `AppStrings` class — all user-facing strings go through ARB.

### Navigation

Imperative throughout (`Navigator.push`/`MaterialPageRoute`). No named-route or go_router setup. The 4 main tabs are never pushed as routes — `MainShell` (`lib/app/main_shell.dart`) keeps them alive in one `IndexedStack` and swaps the visible index via `setState`, so switching tabs preserves scroll position/filters and never re-runs `initState`. `MainShellScope` (`lib/features/widgets/common/floating_nav_bar.dart`) is an `InheritedWidget` exposing `selectTab`/`setLoading` down to any descendant — a main-tab page calls `MainShellScope.of(context).setLoading(true, tab: AppTab.home)` instead of showing its own loading overlay (see [Loading/empty/error state](#loadingemptyerror-state)). `FloatingNavBar` (same file) is built once by `MainShell`, not per-page.

### Virtual try-on

`generate`/`regenerate` on the backend's `OutfitGroup`/`Outfit` API are synchronous — the AI render finishes before the HTTP call returns. `TryOnMixin` (`lib/core/utils/try_on_mixin.dart`) reflects this: a single `await OutfitService().generateOutfit(...)`, no polling, no `Timer`/`Completer`. `TripService.generateOptionOutfit`/`regenerateOptionOutfit` is a second, separate try-on path (used from Trip Plans) that follows the same synchronous single-call shape — don't reintroduce polling in either path; there is no async job/queue on the backend to poll. Note: `Outfit.status`/`Outfit.errorMessage` (`lib/data/outfit.dart`) are parsed from and serialized to JSON but not currently read anywhere in `lib/` — they're a harmless leftover from an earlier job-based design, not something to build new logic on.

### Garment image upload

Three-step flow — `initUpload()` → PUT to signed GCS URL → `completeUpload()`. `analyzeGarment()` is a separate multipart POST called during the add-garment flow to pre-fill metadata (category, color, style, versatility score).

### Auth expiry

See [Error handling (UI)](#error-handling-ui) below for the full request-to-recovery flow and the current/target distinction for how pages should catch it.

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

- **Singleton policy**: plain class by default. Only use `factory` + `_internal()` when the service holds real shared mutable state (an in-memory cache, a live connection) — not for DI convenience, not "for consistency." `GarmentService` and `OutfitService` are the only services that qualify — the latter's `_groupCache` caches `getGroupOutfits(groupId)` per group, invalidated by every one of its own mutation methods (`generate`/`regenerate`/`copy`/`update`/`delete`, on either an outfit or its group).
- **HTTP errors**: for ordinary `BaseService` calls, route non-2xx responses through `BaseService.decodeMap`; it throws `ApiException` with `statusCode` plus parsed `errorCode`/`message` when the backend envelope is valid, and safely falls back when the body is malformed. Never interpolate `res.body`, `response.body`, or a backend `message` into a user-visible exception/string. Error logging must follow [Logging](#logging): log sanitized status/code/context, not an unfiltered response body that may contain signed URLs, identifiers, or personal data. A feature with an established specialized typed decoder (`ClosetAnalysisException`, `MatchLookException`) may keep that path rather than being forced through `decodeMap`. If a status code needs special handling (e.g. treat 404 as success for an idempotent delete), check `res.statusCode` *before* calling `decodeMap`, don't catch and reformat its exception. Idempotent `DELETE`s go through `BaseService.deleteIdempotent` (404/2xx = success, everything else routed through `decodeMap` or a passed-in `errorDecode`) rather than each service re-rolling the branch.
- **JSON numeric parsing**: always `(json['x'] as num?)?.toDouble()` / `.toInt()` — never a raw `as int?`/`as double?` cast on a field that comes from an external API. APIs can serialize the same field as an int or a float depending on the value; a raw cast crashes the first time it doesn't match.
- **Signed URLs**: use `lib/core/utils/signed_url.dart`'s expiry helper rather than re-deriving "is this URL stale" inline at each call site.

## Provider layer rules

- `ref.watch` in `build`, `ref.read` in callbacks — no exceptions.
- `refresh()` follows the standard `AsyncNotifier` shape: `state = const AsyncLoading(); state = await AsyncValue.guard(...)`. This is idiomatic Riverpod and is expected to look the same in every provider — don't extract a shared base class for it.
- Mutation methods use the verb+noun naming from [Naming conventions](#naming-conventions) above.

### Async provider retry policy {#async-provider-retry-policy}

Network-backed `AsyncNotifierProvider` and `FutureProvider` declarations use the shared `appRetryPolicy` from `lib/core/providers/retry_policy.dart`. Do not rely on Riverpod's default retry policy for app HTTP work.

- The policy is a **whitelist**: retry only errors known to be transient — `TimeoutException`, `SocketException`, `http.ClientException`, and `ApiException` with `statusCode >= 500`.
- Retry at most 3 times, using the project's short backoff schedule (currently 300ms → 800ms → 1800ms; ~2.9s total pure backoff). Do not silently widen this to Riverpod's default 10 retries.
- Never retry `AuthExpiredException`, `ApiException` 4xx, known business exceptions such as `ClosetAnalysisException` / `MatchLookException`, deterministic permission/service-disabled errors, unknown ordinary `Exception`s, or Dart `Error`s. Unknown errors fail closed (no retry).
- `AuthExpiredException` already means the normal token-refresh-and-one-request-retry recovery path failed. Provider retry must not delay `AuthExpiredHandler`.
- The provider `retry:` hook governs failures from provider evaluation/recomputation. An explicit provider `refresh()` that catches into `AsyncValue.guard(...)` owns its own resulting `AsyncValue`; do not assume the declaration-level retry hook will retry that method's caught error.
- Do **not** assume `ref.read(provider.future)` by itself is sufficient to drive scheduled retries. If a flow depends on provider retry, keep a real active `watch`/`listen` for the lifetime in which retries are expected. Do not add a fake production listener merely to keep retry alive.
- If a workflow is purely imperative/one-shot and has no reactive consumer, prefer calling the service/repository directly instead of creating a provider solely to await `.future`.
- Retry-related provider tests must keep the provider actively listened to for the duration of the retry assertion; otherwise a `.future`-only test can stall for scheduler/lifecycle reasons rather than policy logic.

When a page renders a provider with `.when(...)`, make sure unrecoverable auth expiry has a real listener/handler path. `ErrorStateWidget` intentionally renders nothing for `AuthExpiredException` because recovery UI belongs to `AuthExpiredHandler`; a page must not rely on the error widget itself to handle session expiry.

## Data models

- `fromJson` parses every numeric field defensively (see [Service layer rules](#service-layer-rules)); prefer a small local parsing closure or inline cast, whichever the file already uses — don't introduce a third idiom into a file that has one.
- Add `copyWith` with `clearX` bool flags for nullable fields **only when the app actually mutates that model's fields in place** (matches `Garment`, `Outfit`). A model that's only ever read, never locally patched, doesn't need one — don't add `copyWith` speculatively.

## UI / page rules

### Comments on layout/spacing/alignment changes

When a change only adjusts layout, spacing, alignment, or which layout widget is used (e.g. swapping a `Row` for a `Stack`, adding a `Positioned`, tweaking padding/alignment to fix spacing), don't add a comment narrating the technique or why it was chosen. The widget tree itself already shows what was done; explaining "a Row would grow taller than X, so use a Stack instead" or similar is noise, not a non-obvious WHY. Keep comments in this area only for a genuinely non-obvious *constraint* that isn't visible from the code — e.g. a fixed number that must match another screen (see "Section headers and field labels" below) — never for describing the layout mechanism itself.

### Widget reuse and extraction

The default design goal is **one canonical Widget per recurring UI concept**. Pages compose those Widgets; they do not create local look-alikes. Reuse is preferred over copying, renaming, or creating a second Widget with slightly different padding, colors, labels, or callbacks.

Throughout this section "**Widget**" is shorthand for any reusable UI unit: a `StatelessWidget` / `StatefulWidget` class, *and* a shared `showXxxDialog()` / `showXxxSheet()` function of the kind already in `common/overlays/` (`showTextInputDialog`, `showPickerSheet`, `showFeedbackOverlay`). The reuse search, canonical-location, duplicate-use, and test rules below apply to both forms — a rename dialog copied into a fourth page is exactly the kind of duplication this section forbids, whether it is a class or a function.

#### Required reuse search before creating UI

Before adding a new Widget class, a new `showXxxDialog()` / `showXxxSheet()` helper, or a non-trivial `_buildXxx()` block:

1. Search `lib/features/widgets/`, `lib/features/pages/`, and call sites for the intended product concept, visible label, layout shape, and likely class names.
2. Inspect existing candidates' constructors and behaviour; filename or class-name differences are not proof that a new Widget is needed.
3. Check `common/` and the relevant domain folder (`garment/`, `outfit/`, `trip/`, etc.).
4. State in the change plan which existing Widget will be reused or why none is compatible.
5. If a compatible Widget exists, reuse it. Do not copy its implementation into the page.

A new Widget is allowed only when the existing candidates cannot represent the required product or behavioural contract without becoming misleading or overly configurable.

#### Canonical Widget rule

When multiple pages show the same product concept — for example the same garment card, outfit grid, section header, empty state, selection row, image frame, action area, or loading treatment — they must use the same canonical Widget.

- Cosmetic differences should normally be expressed through existing theme tokens, a small named variant enum, a slot such as `leading`/`trailing`, or one clearly-scoped optional parameter.
- Prefer a semantic variant enum (a hypothetical `GarmentCardVariant.compact`, say) over clusters of booleans such as `dense`, `smallImage`, `hideSubtitle`, and `flat`. **Target shape, not current state**: no shared Widget in `lib/features/widgets/` carries a variant enum today, so don't go looking for an existing example — reach for this pattern the first time a real second call site needs a cosmetic difference. (Widget-child slots already exist and are fine — e.g. `BottomActionButton`'s optional `leading` icon.)
- Add a variant only when at least one real call site needs it. Do not add speculative variants.
- A visual fix to the canonical Widget should reach every caller that shares the same contract.
- If two existing Widgets are substantially identical, prefer consolidating callers onto the better-named/better-tested one and removing the duplicate in a dedicated, reviewable change.

Do not merge Widgets merely because they look similar. Separate implementations are justified when selection rules, refresh behaviour, navigation, state ownership, accessibility semantics, or product meaning genuinely differ. Record a short reason in code or the migration debt register when the distinction is not obvious.

#### Placement

- Put genuinely domain-independent components in `lib/features/widgets/common/` (`buttons/`, `cards/`, `fields/`, `images/`, `overlays/`).
- Put reusable domain components in `lib/features/widgets/<domain>/`, such as `garment/`, `outfit/`, or `trip/`.
- Keep a single-page component as a private Widget class in the page file when it has a clear independent responsibility but no reuse case yet.
- Do not move a page-specific component into `common/` merely because it has more than one visual element.
- Do not create parallel `common`, `shared`, `base`, and `generic` versions of the same concept. One canonical location wins.

#### Keep a private `_buildXxx()` helper when

A private helper is appropriate when the block is page-specific, short, visually simple, has no independent interaction/loading/error state, and mainly makes `build()` easier to scan. A private helper is not debt merely because it returns a Widget.

Do not use a large `_buildXxx()` helper to hide a reusable card, list item, selector, grid, action area, or stateful section that appears elsewhere. Those belong in a Widget.

#### Use a private page-local Widget when

Extract a block into a private Widget class in the same page file when it has a clear visual responsibility, meaningful conditional layout or local UI state, can rebuild independently, or would benefit from focused testing — even if only one page uses it today. Keep screen-level provider/service orchestration and navigation in the Page.

Do not move business logic into a presentational Widget merely to shorten a Page. A presentational Widget may render data, own purely local UI state (focus, expansion, animation, temporary selection), and emit user intent through named callbacks; it should not call REST services directly, know auth/token-refresh details, or mutate unrelated providers.

#### Duplicate-use threshold

- **First use:** a page-local helper or private Widget is acceptable.
- **Second substantially-identical use:** the trigger is *adding* the second copy. If this change is what introduces it, reuse or extract a shared canonical Widget in the same change instead — “faster for now” is not sufficient, and keeping two copies requires a concrete documented product/behaviour difference. If the second copy *already exists* and you are only editing near it for an unrelated reason, you are not required to extract it in that change — that is [migration debt](#migration-debt-register-flutter) (item 4), revisited on its own trigger — but you must not let your change add a third.
- **Third substantially-identical use:** duplicate implementations are forbidden. Consolidate them before adding the third caller unless the documented contracts genuinely differ.

Similar names are not enough to establish duplication, and different names do not prove uniqueness. Compare structure, product meaning, interaction, data source, loading/error states, refresh behaviour, accessibility, and future change ownership.

#### Avoid parameter explosion and false reuse

Do not create a “universal” Widget whose constructor mirrors most of the parent State. Warning signs include many unrelated primitive parameters, several independent mode booleans, numerous implementation-detail callbacks, or controllers passed only to move code out of the Page.

When extraction causes parameter explosion, prefer in this order:

1. Reuse an existing cohesive domain model.
2. Pass a small immutable view-data object when presentation data genuinely differs from the domain model and has multiple meaningful fields.
3. Use a small semantic variant or slot.
4. Keep the component page-local if its contract is genuinely page-specific.
5. Move orchestration into a provider/controller if the real problem is state ownership, not rendering.

Do not create a one-use view-data class or abstraction solely to make a constructor appear shorter.

#### Page complexity review

Line count alone does not make a Page a god object. Review a Page when it coordinates unrelated business flows, owns several independent mutation/loading flags, contains multiple large interactive sections, hides substantial conditional behaviour in `_buildXxx()` methods, or requires reading most of the file to understand one section.

When a Page needs decomposition:

1. Inventory existing shared Widgets first.
2. Reuse them before extracting anything new.
3. Extract independent leaf UI sections one at a time.
4. Keep screen-level orchestration in the Page.
5. Move business/state logic to the appropriate provider/service rather than into a visual Widget.
6. Keep each extraction independently testable and reviewable; do not rewrite the whole Page merely to reduce line count.

#### Naming

- Reusable classes use a product-facing noun: `GarmentCard`, `TripDayCard`, `OutfitGrid`.
- A shared dialog or sheet exposed as a function is named for the user-facing verb, matching the `_showXxxDialog()` convention in [Naming conventions](#naming-conventions): `showTextInputDialog`, `showPickerSheet` — not `textInputWidget` or `renameDialogHelper`.
- Private page-local classes use an underscore: `_TripSummaryCard`, `_PreferenceSection`.
- `_buildXxx()` names describe the rendered responsibility: `_buildPackingSummary()`, not `_buildSection2()`.
- Avoid vague or parallel names such as `CommonCard`, `CustomWidget`, `ReusableContainer`, `NewGarmentCard`, or `GarmentCardV2`. Extend or replace the canonical Widget instead.

#### Tests and visual verification

Add or update a Widget test when a shared/extracted Widget has conditional states, interaction, selection behaviour, loading/empty/error presentation, callbacks whose arguments matter, or layout shared by multiple screens.

After creating, consolidating, or changing a shared Widget:

1. List every caller found by repository-wide search.
2. Run the focused Widget/page tests and the full test suite.
3. Run `flutter analyze` and `git diff --check`.
4. Manually verify every affected screen that lacks render coverage, including spacing, scrolling, navigation, loading overlays, empty/error states, accessibility labels, and bottom actions.
5. Confirm that the change did not create a second near-duplicate Widget elsewhere.

### Loading/empty/error state

- **Main-tab pages** (`HomePage`, `ClosetPage`, `OutfitsPage`, `TripsPage`): route a tab-scoped fetch's loading state through `MainShellScope.of(context).setLoading(...)` — the shell paints one overlay above the nav bar. A cross-tab shared action helper that doesn't know which tab it's running under (e.g. `trips_page.dart`'s `handleCreateTrip`/`handleDeleteTrip`, called from both Home and Trips, or `main_shell.dart`'s own `_openAddOutfit`) may use a modal `LoadingOverlay` dialog instead, since `setLoading` is keyed per-`AppTab`. Outside of that carve-out, don't build a page-local loading overlay on a main tab.
- **Pushed pages**: `Stack` with `Positioned.fill(child: LoadingOverlay(...))`, conditionally shown.
- **Brief in-place fetches**: `AppSpinner`.
- **Empty lists**: `EmptyStatePlaceholder` — never hand-roll an empty-state `Text`.
- **A full "start doing the thing" empty state** (icon + bold title + subtitle + an `AccentPillButton` call-to-action, centered across the whole tab body): still `EmptyStatePlaceholder`, with `fillAvailableSpace: true` (Closet/Outfits/Trips/Trip Suitcase's own empty states all use this — don't hand-roll a `Center`/`SingleChildScrollView` wrapper at the call site, the widget does it internally). Pass `bottomInset: AppDimens.mainNavBarClearance` only on a main tab — its `MainNavBar` is a floating overlay `MainShell` paints on top, not a `Scaffold.bottomNavigationBar`, so the tab's own body isn't actually shortened for it, and without `bottomInset` the centered content reads as sitting below true-center. A pushed page (no floating nav bar) leaves it at the default `0`. Pass `pinnedTop` when a sibling above the centered content can change height on its own (e.g. Trip Suitcase's collapsible packing-advice card) — it sits in its own layer so that resizing never shifts the centered content, which a plain scrolling layout can't guarantee.
- **Provider `.when()` error branches**: `ErrorStateWidget`.

### Guarding costly / mutating actions against double-invocation {#double-invocation-guard}

A handler that starts an AI render, creates/copies a record, or makes any other backend call that is expensive or wrong to run twice must hold a **synchronous re-entrancy guard**: a `bool` field set as the handler's first statement — *before any `await`* — and cleared in a `finally`.

```dart
Future<void> _doCostlyThing() async {
  if (_thingInFlight) return;
  setState(() => _thingInFlight = true);
  try {
    // ... awaits, dialogs, the actual call ...
  } finally {
    if (mounted) setState(() => _thingInFlight = false);
  }
}
```

This is a plain local flag, not a job/queue — it does not reintroduce the polling this codebase deliberately removed (see [Virtual try-on](#virtual-try-on)).

Hiding or disabling the trigger button is **not** a substitute:

- A flag the operation only raises *after* its first `await` — a pre-flight suitcase fetch, a `SharedPreferences` read, a confirm dialog, or a loading flag set inside a helper (e.g. `performTryOn` raising `isOutfitLoading`) — leaves the button live during that first `await`, so a double-tap lands two calls before the flag is ever set.
- A full-screen `LoadingOverlay` only absorbs taps from the frame *after* `setState`, and `BottomActionButton`'s `AnimatedSwitcher` keeps the outgoing button hit-testable for ~200ms after it is told to hide.

When the action has a pre-flight phase, keep the **guard flag distinct from the visual "generating" flag** — drive the overlay off the latter so it doesn't show over the confirm dialog — and wire the guard flag into the trigger's own disabled/hidden condition so the button also *looks* unavailable during the pre-flight phase.

**Current state.** `_regenerateImage` / `_setCover` / `_addToMyOutfits` (`outfit_details_page.dart`) and `_generateSelectedDayOutfit` (`trip_details_page.dart`) already raise their flag synchronously and are the pattern to copy. `_startTryOn` / `_handleCompleteWithAiTap` (`add_outfit_page.dart`) and `_generatePlan` (`trip_details_page.dart`, via the `_generatePlan` → `_generatePlanFlow` wrapper) were brought in line with it.

### Error handling (UI) {#error-handling-ui}

**Actual request-to-recovery flow.** A `BaseService`-mixed-in call that gets HTTP 401 does not throw immediately:

```
HTTP 401
  → BaseService.withAuth: silent token refresh + retry the original request once
  → refresh/retry unrecoverable (no stored refresh token, refresh endpoint answers non-200 / without a new token pair, or the retry 401s again)
  → AuthExpiredException thrown
  → either caught by an imperative page flow, or surfaced in provider AsyncValue.error
  → AuthExpiredHandler.handle(context) from the page catch/listener
  → static _isHandling flag dedupes concurrent triggers (e.g. several tabs' listeners firing at once)
```

So "`AuthExpiredException` on 401" really means *unrecoverable* 401 — most transient 401s never reach a page's `catch` at all because `withAuth` already recovered from them. A transport error or timeout *on the refresh call itself* is not an auth problem: since `8036b16` it propagates as itself (`TimeoutException` / `ClientException`), not as `AuthExpiredException`, so a page's generic `catch` handles it as "network/server unavailable".

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

`on AuthExpiredException` is its own clause, checked before the generic `catch` for **imperative page/feature-layer network calls**. A bare `try { ... } finally { ... }` around such a call is a bug because it hides the user-facing fallback path. Provider `build()` methods are different: they intentionally allow errors to propagate into Riverpod so `AsyncValue` + `appRetryPolicy` can own retry/error state; provider `refresh()` methods may intentionally capture errors with `AsyncValue.guard(...)`.

For generic API failures, keep technical detail in `debugLog` and derive user-facing copy through `apiErrorMessage(_l10n, e, fallback: ...)` when applicable. The backend `message`, raw response body, HTTP operation label, storage object path, and exception `.toString()` are not UI copy. Cross-cutting `error_code` mappings belong in `lib/core/utils/api_error_text.dart`; do not recreate the same `switch (errorCode)` in multiple pages.

**Current state.** Every page/feature-layer `catch` site uses the target `on AuthExpiredException` clause — the old `if (e is AuthExpiredException)` shared-`catch` shape has been fully migrated out, and `8036b16` removed the last `if (e is AuthExpiredException)` catch-guard (the one inside `BaseService.withAuth`; `withAuth` now has no `try`/`catch` at all).

Remaining `is AuthExpiredException` checks in `lib/` are **provider-state inspections**, not generic `catch` branches, and are legitimate. They appear in listener/reporting paths such as `main_tab_async.dart`, `home_page.dart`, `settings_page.dart`, `style_taste_page.dart`, `trip_suitcase_page.dart`, and `garment_outfits_page.dart`, plus `error_state_widget.dart` (which renders nothing for auth expiry because the listener owns recovery UI).

These inspect an `AsyncValue.error` *value*; they are not the handle-vs-fallback `catch` shape. Don't reintroduce `if (e is AuthExpiredException)` inside a generic `catch` (it's in [Forbidden patterns](#forbidden-patterns-flutter)). Any new page that uses `.when(...)` with `ErrorStateWidget` must also have a reachable auth-expiry listener/handler unless a parent shell already guarantees one for that exact provider.

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
- If two pages need the same card chrome (border, padding, shadow), reuse or extract one shared Widget in `lib/features/widgets/common/cards/`; do not create two private `_buildCardShell` copies. Follow the full decision rules in [Widget reuse and extraction](#widget-reuse-and-extraction).
- A field's own caption is `LabeledField` (`lib/features/widgets/common/fields/labeled_field.dart`) — label + a fixed 8px gap + the field, matching Garment Details/Account/AI Model's forms. When a dialog or form stacks more than one `LabeledField`, the gap *between* them is `20` (see Garment Details' Category → Product Type → ...; Plan a Trip's Trip Name → Destination & Dates matches this). Don't re-derive or re-justify either number with a fresh comment — this bullet is that record.

### Corner badges (`CardCornerBadge`)

`CardCornerBadge` (`lib/features/widgets/common/cards/card_corner_badge.dart`) has two established, deliberately different treatments. Match whichever one applies and don't add a new comment re-justifying the color/size/border choice at the call site — this section is that explanation.

- **Photo-overlay family** — a badge floating on a photo/full-bleed image: `FavoriteCard`, `RemovableCard`, Outfit Details' favourite heart + "⋮" menu trigger, Trip Details' regenerate icon (via `TodayOutfitIdea`), Home's "worn today" icon. Shape: `backgroundColor: AppColors.surfaceTranslucent`, `border: Border.all(color: AppColors.borderSubtle)`, `boxShadow: const []`, `size: 36`, `iconSize: 20` (Home's "worn today" badge uses `24` — the standing-figure glyph carries more internal whitespace and needs it to read at the same visual weight; that's the one deliberate exception). Color: the **neutral/resting state is always `AppColors.hintText`** — an active/toggled-on state gets its own color (favourited heart → `AppColors.favorite`, marked "worn today" → `AppColors.accent`) — the resting state is never `AppColors.icon` (reads too dark/heavy against this family) and never a raw color.
- **List-row action-badge family** — a badge on a plain card row, not a photo: Add Outfit's lock/remove, Outfit Edit's remove, Trip Legs Editor's remove. Shape: `backgroundColor: AppColors.placeholderSurface`, no `border`, default shadow, `hitTargetSize: Size(24, AppDimens.minTouchTarget)`. Color: `AppColors.icon` — this family is a deliberately distinct treatment for a different surface, not "the photo-overlay family done slightly wrong," so its darker icon color is correct here and must never be changed to match the photo-overlay family above.
- A badge that's inherently a warning/alert rather than a toggle (e.g. `garment_list_card.dart`'s soft-deleted-garment badge, `AppColors.error`) is its own case outside both families above.

### Dialog primary button disabled state

`AppDialog`'s `onPrimary` (`lib/features/widgets/common/overlays/app_dialog.dart`) is nullable — pass `null` for a form dialog whose action only makes sense once required fields are filled in (e.g. `TripCreateDialog`'s Create button, gated on a name + at least one destination) **or** once the field(s) actually differ from their starting value (e.g. `showTextInputDialog`'s Save button, gated on the trimmed text being non-empty and different from `initialValue` — a rename dialog with nothing to rename is the same "nothing to submit" case as a required field left blank). It renders as `disabledBackgroundColor: AppColors.borderSubtle` / text `AppColors.hintText`, staying visible but unpressable — unlike `BottomActionButton`, which hides entirely when unavailable (see [Guarding costly / mutating actions against double-invocation](#double-invocation-guard)); a form dialog wants its buttons visible at all times, `BottomActionButton`'s async-action triggers don't. Don't reintroduce the pre-flight `showSnackBar`-on-submit validation this replaced — the disabled button already prevents the invalid submit. To make the gate reactive to a `TextEditingController`, wrap the `AppDialog` in a `ValueListenableBuilder<TextEditingValue>` listening to the same controller (see `showTextInputDialog`) rather than a `StatefulWidget` — the controller already is the state.

### Dialog content directly under the title

A plain `body: String` always renders as `AppTextStyle.medium16` (black, `AppColors.textPrimary`), centered — `AppDialog` controls this internally (see `auth_handler.dart`'s session-expired dialog, every delete/regenerate confirmation, `settings_page.dart`'s logout confirm). A dialog that instead passes a custom `content: Widget` and opens it with its own hand-written explanatory sentence (a description sitting directly under the title, before any field/list) must style that sentence identically — `AppTextStyle.medium16`, centered, no color override — so every dialog's title-adjacent text reads the same regardless of whether it came through `body:` or the first line of a `content:`. `add_outfit_page.dart`'s Finish Outfit dialog is the one dialog with such a sentence today. This rule is about that opening sentence only — it doesn't prescribe how a dialog styles its actual form fields/list rows further down `content:`, which are a different concern.

### Localization

- **Target (new code, and any page you substantively touch):** define `AppLocalizations get _l10n => AppLocalizations.of(context);` once and use `_l10n.xxx` throughout — never call `AppLocalizations.of(context).xxx` inline more than once in the same file.
- **Current state:** about half of `lib/features/pages/` follows this; ~14 pages still call `AppLocalizations.of(context)` inline (see [Migration debt register](#migration-debt-register-flutter) item 1). This is the accessor idiom only — those pages' strings are already all ARB-sourced. Don't batch-migrate the 14; add the getter to a file when you're editing it for another reason.
- No hardcoded `Text('...')` literals for user-facing copy — this part *is* fully current across the app. Every string, including nouns interpolated into a template string (`_l10n.selectItemTitle('Accessory')`), goes through ARB.

### Design tokens

These are the **target for new and substantively-touched code**. `lib/features/` is only partially migrated — see [Migration debt register](#migration-debt-register-flutter) item 2.

- Never `Color(0x...)` in the **UI / theme layer** — always `AppColors.*`. Exception: `garment.dart`'s `GarmentColor.color` swatch map is a *domain* palette (the real-world colour of a garment), not a theme token — its hex literals are intentional and are **not** a violation of this rule.
- Prefer an `AppDimens` constant over a raw pixel literal that duplicates one (`16`/`12` for spacing, `EdgeInsets.fromLTRB(16, 16, 16, 24)` for page grid padding — use `AppDimens.sectionSpacing`/`AppDimens.cardSpacing`/`AppDimens.pageGridPadding`). If a new spacing/radius value is genuinely needed in more than one place, add it to `AppDimens` rather than repeating the literal.
- `BorderRadius.circular(AppDimens.cardRadius)` for cards — check `AppDimens` before writing a raw `circular(N)`; only use a raw literal when the value is deliberately different from every existing token. Note: `lib/features/` still contains many raw `circular(N)` literals not yet reconciled against the tokens — fix them in a widget when you're already editing its chrome, not as a sweep.

## Logging

- Every public service method that performs an HTTP call opens with `debugLog('--- methodName: relevant params ---');`, placed *after* any early-return cache check or parameter resolution needed to make the logged values meaningful — e.g. `GarmentService.getGarment` and `OutfitService.getGroupOutfits` both log only once past their cache-hit fast path, and `OutfitService.generateOutfit` resolves `groupId` before logging so the line carries a real value, not `null`. `withAuth` does not add a second entry log. `decodeMap` may emit a failure-only diagnostic, but it must be sanitized (status / error code / safe operation context), never a blanket dump of the raw response body. Methods that don't perform an HTTP call (pure getters, trivial wrappers) aren't required to log.
- **Never log**: access tokens, `Authorization` header values, signed URLs, photo/image bytes or data URIs, email addresses, or any other personally-identifying data. A log line naming *which* garment/outfit/trip id was involved is fine; logging the credential or the payload that proves who the user is, is not. Also don't log a local filesystem path to a user-picked image — it isn't a credential, but it exposes device directory layout for negligible debugging value (`MatchLookService.uploadReference` still does this — [Migration debt register](#migration-debt-register-flutter) item 10; new code must not copy it).

## Canonical example files (Flutter)

Each file below is canonical **only for the specific things listed** — it is not a "copy the whole file" template, and known violations elsewhere in the same file are called out so they aren't copied along with the good parts.

| Category | File | Demonstrates | Known violations — do not copy these parts |
|---|---|---|---|
| Service | `lib/core/services/trip_service.dart` | Canonical **for these concerns only**: `_baseUrl` convention, `decodeMap`-based error handling, the "one `debugLog` per HTTP method" habit | Not to copy: the `debugLog` lines omit the colon separator ([Logging](#logging) specifies `'--- updateTrip: id=$tripId ---'`; the file writes `'--- updateTrip id=$tripId ---'`). The full-request-body / day-by-day-summary logging this file used to carry was removed in `6255da9` (see the *Recently resolved* note in the [Migration debt register](#migration-debt-register-flutter)) — every method now logs only the `--- method id/params ---` line |
| Service (singleton) | `lib/core/services/garment_service.dart` | Cache-backed singleton shape, `.timeout()` on every call, cache kept coherent after a successful mutation, `deleteIdempotent`-based delete | `uploadImage()` is a redundant single-caller wrapper over `BaseService.putJpegToSignedUrl` ([Migration debt register](#migration-debt-register-flutter) item 3) — call `putJpegToSignedUrl` directly in new code |
| Service (minimal shape) | `lib/core/services/daily_outfit_service.dart` | Minimal stateless (non-singleton) service shape | — |
| Provider | `lib/core/providers/garments_provider.dart` | `AsyncNotifier` `refresh()` shape, verb+noun mutation naming, `retry: appRetryPolicy` on a network-backed provider | — |
| Data model | `lib/data/outfit.dart` | `copyWith` `clearX` flags, extracted cache-key helper (`outfitImageCacheKey`), `num`-tolerant `parseId`, `OutfitGroupType` enum with `apiValue`/`fromApiValue` | — |
| Page | `lib/features/pages/outfit_details_page.dart` | Field→`initState`→`build`→helper ordering, `_l10n` alias getter, `BottomActionButton` wiring, pushed-page `Positioned.fill(LoadingOverlay)` loading, `on AuthExpiredException` clause shape, synchronous re-entrancy guard on costly actions (`_regenerateImage`/`_setCover` — see [Guarding costly / mutating actions against double-invocation](#double-invocation-guard)) | one raw `BorderRadius.circular(16)` instead of `AppDimens.cardRadius` |
| Shared widget | `lib/features/widgets/common/buttons/bottom_action_button.dart` | Full compliance — colors via `AppColors`, no hardcoded text, documented literals | — |
| Shared grid | `lib/features/widgets/outfit/outfit_grid.dart` / `lib/features/widgets/garment/garment_grid.dart` | Canonical grid per product concept: shared delegate + padding + (for `OutfitGrid`) empty state / refresh; per-screen item wrappers stay at the call site via `itemBuilder`. `GarmentGrid.gridDelegate` is exposed for the one raw `SliverGrid` call site | — |
| Shared filter state | `lib/features/widgets/common/buttons/garment_color_type_filter.dart` / `outfit_season_style_filter.dart` | Non-widget state class that owns a `FilterButton`'s data: derives the option lists, holds the selected sets, `apply()`s the filter. The "move orchestration to a controller" resolution for repeated filter blocks | — |
| Shared dialog helper | `lib/features/widgets/common/overlays/text_input_dialog.dart` | `showXxxDialog()` function form of a shared overlay: one canonical single-field-input dialog behind every rename flow (trip / outfit / garment), callers differ only in `title`/`hint` and result handling | — |

When adding a new page/service/provider/model, start from the primary example above for the property you need and follow its shape for that property — don't assume the rest of the file is equally clean.

## Forbidden patterns (Flutter)

- Raw `Color(0x...)` instead of `AppColors`.
- A hardcoded `Text('...')` for user-facing copy instead of `_l10n.xxx`.
- Hand-rolled empty/error state widgets when `EmptyStatePlaceholder`/`ErrorStateWidget` exist.
- `try { ... } finally { ... }` around a network call with no `catch`.
- A service building its own HTTP-error message string instead of going through `BaseService.decodeMap`.
- A raw `as int?`/`as double?` cast on a JSON field sourced from an external API.
- A bare provider mutation-method verb (`add`/`remove`) instead of verb+noun (`addGarment`/`removeGarment`) in new code.
- Copy-pasting a substantially-identical private helper, Widget (class *or* `showXxx()` dialog/sheet function), filter-option list, dialog builder, or card/list/grid implementation into a second file. When your change adds the second copy, reuse or extract a canonical shared component instead unless a concrete product/behaviour difference is documented; a third equivalent implementation is forbidden (see [Widget reuse and extraction](#widget-reuse-and-extraction)).
- Creating a new Widget without first searching existing common/domain Widgets and their call sites for a compatible canonical component.
- Creating parallel near-duplicates distinguished only by vague names (`CommonX`, `CustomX`, `NewX`, `X2`, `XCardV2`) or cosmetic defaults that should be a semantic variant/theme token.
- Expanding a shared Widget into a boolean-heavy universal component instead of keeping genuinely different product contracts separate.
- A new abstraction layer, base class, or wrapper introduced for something used in exactly one place "for future flexibility."
- `BottomActionButton` placed inline in the body instead of via `Scaffold.bottomNavigationBar`.
- An AI-render / create / copy / paid-call handler with no synchronous re-entrancy guard before its first `await` — relying only on a later-set loading flag, a hidden/disabled button, or the loading overlay to stop a double-tap (see [Guarding costly / mutating actions against double-invocation](#double-invocation-guard)).
- A network-backed `AsyncNotifierProvider` / `FutureProvider` that falls back to Riverpod's default retry instead of declaring `retry: appRetryPolicy`, unless a concrete exception is documented next to the provider.
- Depending on a `.future`-only read as the sole mechanism that keeps a retry-dependent provider alive. Use a real reactive watcher/listener for reactive state, or call the service directly for a one-shot imperative workflow.
- Showing `e.toString()`, `error.toString()`, raw `res.body` / `response.body`, backend `message`, HTTP operation labels, signed URLs, bucket/object paths, or other technical exception detail as user-facing UI copy.
- Logging an access token, `Authorization` header, signed URL, image payload, email, or other personal data (see [Logging](#logging)).
- The `if (e is AuthExpiredException)` shape inside a `catch` (use the `on AuthExpiredException` clause instead — see [Error handling (UI)](#error-handling-ui)). The codebase is fully migrated; the only `is AuthExpiredException` uses left are three legitimate `AsyncValue.error` checks in build/listener callbacks, which are not `catch` blocks.

## Migration debt register (Flutter)

Known gaps between the current code and the rules above. Each is deliberately **not** mass-fixed as a side effect of unrelated work — touch it only when its *trigger* fires, or in a dedicated pass. New code still follows the rule.

**Recently resolved — no longer debt, listed only for cross-reference:**

- **Widget-reuse slice (5 batches):** the 5 hand-rolled garment grids collapsed onto `GarmentGrid` (`lib/features/widgets/garment/garment_grid.dart`, + its `gridDelegate` constant for the one sliver call site); the colour/product-type and season/style filter state (option lists + `apply` + the 2-group `FilterButton`) moved into `GarmentColorTypeFilter` / `OutfitSeasonStyleFilter` (`lib/features/widgets/common/buttons/`) — `closet_page.dart` deliberately keeps its own colour filter (enum-ordered, category-scoped); the "label + 8px gap + field" scaffold became `LabeledField` (`lib/features/widgets/common/fields/`); the outfit/version carousel dots became `CarouselDotsIndicator` (`lib/features/widgets/common/`); and `SelectAccessoryPage` was folded into `SelectGarmentPage` (now takes a nullable `category`), so the file is gone.
- `BaseService.withAuth`'s `/auth/refresh` POST had no timeout → fixed in `8036b16`: 15s cap; a `TimeoutException` / transport error on the refresh call now propagates unchanged instead of being masked as `AuthExpiredException`.
- `Garment.fromJson` / `fromTripItemJson` cast `id` / `garment_id` with a raw `as int?` → fixed in `894d31e`: all three sites go through `Garment._parseNullableId` (int / integer-valued double → int; `null` → `null`; fractional / `NaN` / `Infinity` → `FormatException`; numeric string / bool → `TypeError`, unchanged).
- `TripService` logged full request / response payloads → **removed in `6255da9`**. `createTrip` no longer logs `jsonEncode(body)` (which had carried the trip name, `legs` / location names, dates and free-text activity strings); `getTrip` no longer logs a day-by-day response summary (which had included the trip's dates); the private `_summarizeDays` helper that built that summary was deleted. Every `TripService` HTTP method is back to a single id-only `--- method id=… ---` line. Endpoints, request bodies, response parsing, exception behaviour, timeouts and public signatures were untouched by that change.
- **Frontend API-error leakage**: `BaseService.decodeMap` now throws safe `ApiException` values instead of embedding the raw HTTP body in `Exception.toString()`; page catches log technical detail only in debug builds and show ARB copy via `apiErrorMessage(...)`. `FACE_REFERENCE_NOT_FOUND`, `BODY_REFERENCE_NOT_FOUND`, and `FILE_NOT_FOUND` have shared localized mappings; unknown codes fall back safely.
- **Profile fetch / reference-image isolation**: `profileProvider` now fetches `/users/me` once through `getMyProfileData()` instead of three parallel calls to the same endpoint. Face/body signed-URL load failures stay card-local in My Virtual Model and offer the existing re-upload action; they do not fail the provider or erase the rest of the profile.
- **Riverpod retry policy**: all current network-backed Future-based providers use the shared whitelist `appRetryPolicy` (max 3 retries / ~2.9s pure backoff). `AuthExpiredException`, 4xx, business errors, permission errors, unknown exceptions and Dart `Error`s do not retry; Style Taste and Trip Suitcase auth-expiry listener gaps were closed.

### 1. `_l10n` getter not adopted in ~14 pages

- **Scope**: ~14 files in `lib/features/pages/` call `AppLocalizations.of(context)` inline instead of the `AppLocalizations get _l10n =>` alias — e.g. `trips_page.dart`, `style_taste_page.dart`, `closet_page.dart`, `outfits_page.dart`, `home_page.dart`, and the `select_*` / `trip_*` selection pages. Strings are already all ARB-sourced; this is the accessor idiom only.
- **Risk**: Low — readability only, no behaviour or localization-correctness impact.
- **Deferred reason**: Each conversion is a whole-file edit, and most of these pages have no test coverage, so a batch rename is high-churn and hard to review for zero functional gain.
- **Trigger for revisiting**: When you substantively touch one of these pages for another reason, add the getter and convert that file then. A dedicated sweep is acceptable but low priority.

### 2. Design-token migration incomplete in `lib/features/`

- **Scope**: Dozens of raw `BorderRadius.circular(<literal>)` calls and a few raw spacing literals remain across `lib/features/pages/` and `lib/features/widgets/`. Only files touched by the consistency-refactor slices were cleaned. (Not `Color(0x...)` — those are already absent from the UI layer; the `garment.dart` swatch palette is an intentional domain exception, see [Design tokens](#design-tokens).)
- **Risk**: Low — visual constants; a stale value is a design nit, not a bug.
- **Deferred reason**: Needs a judgement call per literal (stale duplicate of a token vs. deliberately distinct value), so it can't be mechanically swept.
- **Trigger for revisiting**: When editing a widget's chrome, replace that widget's literals with `AppDimens.*` (adding a token if the value recurs in 2+ places).

### 3. `GarmentService.uploadImage` thin wrapper

- **Scope**: `garment_service.dart`'s `uploadImage()` is a 2-line pass-through to `BaseService.putJpegToSignedUrl` with a single remaining caller (`garment_details_page.dart`). The other three upload sites already call `putJpegToSignedUrl` directly.
- **Risk**: Very low — works correctly; it's redundant indirection and trips the "no wrapper for a single call site" forbidden pattern.
- **Deferred reason**: `021349c` folded in the implementation but stopped short of deleting the wrapper and repointing the last caller.
- **Trigger for revisiting**: Next time `garment_details_page.dart`'s add-garment flow is touched — inline the `putJpegToSignedUrl` call and delete `uploadImage`.

### 4. Widget-level duplicate `_buildXxx` helpers and loading/empty/error shape drift

- **Scope**: Copy-pasted private `_buildXxx` blocks and slightly divergent hand-rolled loading/empty/error layouts remain in `lib/features/` beyond the widgets the refactor extracted (`OutfitGrid`, `GarmentGrid`, `main_tab_async`, `ExpandableInsightBody`, `CarouselDotsIndicator`, …). Known remaining: `select_outfit_group_page.dart` still hand-rolls its outfit grid (for the virtual "new group" leading card); the single-select bottom sheet (`RadioGroup` + `PickerSheetHeader` + `ListTile`s) is still open-coded in `garment_details_page.dart` / `account_page.dart` / `lifestyle_page.dart` / `settings_page.dart`; the "titled card + subtitle" header is open-coded in `lifestyle_page.dart` / `style_taste_page.dart` / `my_virtual_model_page.dart`; `add_outfit_page.dart`'s `_slotRow` is a ~130-line helper wrapping `AppListCard`.
- **Risk**: Low-medium — maintainability; a fix applied to one copy can miss the others.
- **Deferred reason**: Cross-cutting; each extraction needs its own design and visual QA.
- **Trigger for revisiting**: When any listed page/helper is substantively touched, perform the required reuse search from [Widget reuse and extraction](#widget-reuse-and-extraction). At the **second** substantially-identical use, reuse or extract a canonical shared Widget in that change unless a concrete product/behaviour difference is documented. A **third** equivalent implementation is not allowed. A genuine difference is not duplication: `select_outfit_group_page.dart` may keep its own grid only while its custom leading-card and copy-into-group selection contract genuinely differ (or give `OutfitGrid` a `leading` slot). When a loading/empty/error state is edited, align it with `EmptyStatePlaceholder`, `ErrorStateWidget`, or the standard shapes in [Loading/empty/error state](#loadingemptyerror-state).

### 5. UI render-test gaps

- **Scope**: Many page files and shared widgets still have no render/widget test. Coverage has expanded across services, data models, providers (including retry policy), several large/detail pages, My Virtual Model, Style Taste, Trip Suitcase auth handling, and shared widgets, but it is still not comprehensive.
- **Risk**: Medium — `flutter analyze` + `flutter test` do **not** catch a layout / navigation / loading regression on an untested page.
- **Deferred reason**: Page render tests need per-page harness setup (preloaded providers, mock HTTP, real l10n delegates); they're being added opportunistically, not in one batch.
- **Trigger for revisiting**: Any change to an untested page's visual layout, loading state, or navigation flow — do manual QA of that screen before commit (step 3 of [Pre-change / post-change checks](#pre-change--post-change-checks-flutter)), and add at least a smoke test for that page if feasible.

### 6. Backend daily try-on quota error not surfaced specifically

- **Scope**: The backend enforces a per-user daily try-on generation limit. Flutter now has a shared `ApiException` + `apiErrorMessage(...)` mapping path, but the quota's exact backend `error_code` is not yet mapped to dedicated "limit reached" copy, so it still falls through to the operation-specific generic fallback.
- **Risk**: Low-medium — the failure *is* shown, just not explained; a user at the cap sees a vague error.
- **Deferred reason**: Needs a product decision on the message and confirmation of the exact `error_code` the backend returns; outside the consistency-refactor scope.
- **Trigger for revisiting**: When the daily / trip try-on UX is next revised, or when the backend's quota `error_code` is confirmed — add an `error_code` branch with an ARB string.

### 7. Backend consistency work — out of scope for this repo

- **Scope**: `virtual-wardrobe-backend` has its own layering / naming debt (service-layer `db.query`, a route-layer violation in `analyze_instant`, dead job-era code). Tracked in that repo against its own `CLAUDE.md`.
- **Risk**: N/A here — no Flutter code involved.
- **Deferred reason**: The consistency refactor was explicitly scoped to the Flutter frontend only.
- **Trigger for revisiting**: A dedicated backend pass, driven from the backend repo — never from frontend work.

### 8. Third-party HTTP calls without a timeout

- **Scope**: Two direct `package:http` calls that don't go through `BaseService` (which always caps its own calls) have no `.timeout()`:
  - `weather_provider.dart`'s Open-Meteo forecast fetch (`_fetchWeatherApi`).
  - `location_picker_page.dart`'s Open-Meteo geocoding search (`_search`).
- **Risk**: Low-medium — if the third-party request stays pending, the provider / page can sit in a loading state indefinitely. Neither call touches auth or user data, and both already have status/error handling around the response.
- **Deferred reason**: Not on the `BaseService` path, so each needs its own timeout-UX decision (duration, error copy, retry) and its own test approach; outside the core service slice the consistency refactor covered.
- **Trigger for revisiting**: Next time the weather or location integration is touched, or if a request-hang / stuck-loading bug is reported — add a consistent `.timeout()` and test the post-timeout UI / provider state.

### 9. `location_picker_page.dart` passes raw JSON coordinates into `double` fields

- **Scope**: `_search` builds `LocationResult(latitude: r['latitude'], longitude: r['longitude'], ...)` straight from the decoded Open-Meteo geocoding JSON — the `dynamic` values go into `LocationResult`'s `double` fields with no `num`-tolerant conversion. `trip.dart` parses the same fields correctly with `(json['latitude'] as num?)?.toDouble()`.
- **Risk**: Low — Open-Meteo returns fractional coordinates in practice, but an integer-valued response would throw a `TypeError` at construction.
- **Deferred reason**: `location_picker_page.dart` has no render/unit test, so the fix wants a parsing change plus at least a smoke test added in the same pass.
- **Trigger for revisiting**: Next time the location picker is touched — switch to `num`-tolerant `.toDouble()` parsing and test int / double / null / malformed input.

### 10. `MatchLookService.uploadReference` logs a local image path

- **Scope**: `match_look_service.dart`'s `uploadReference` opens with `debugLog('--- uploadReference: $localImagePath ---')` — the device-local filesystem path of the user-picked image. It is not the image bytes, a data URI, or a signed URL, so it isn't a [Logging](#logging) "never log" violation, but a local path exposes device directory layout for negligible debugging value.
- **Risk**: Low.
- **Deferred reason**: Documentation-only pass; the one-line code fix isn't mixed into it.
- **Trigger for revisiting**: Next time `MatchLookService` is touched — reduce the line to the method name only (`--- uploadReference ---`). New code must not log local file paths.

### 11. `BaseService.decodeMap` still logs the raw error response body in debug builds

- **Scope**: The recent error-handling hardening removed raw response bodies from `Exception.toString()` and production UI, but `decodeMap` still writes the full non-2xx response body to `debugLog`.
- **Risk**: Low in release builds because `debugLog` is debug-gated, but the body can still contain backend `message`, identifiers, signed URLs, object paths, or other data that the [Logging](#logging) rules say not to log wholesale.
- **Deferred reason**: The leakage-to-UI bug is already closed; changing diagnostic shape should be a small dedicated pass so failure observability is preserved while sensitive payload dumping is removed.
- **Trigger for revisiting**: Next time `BaseService.decodeMap` / `ApiException` logging is touched — replace raw-body logging with sanitized `statusCode`, parsed `errorCode`, and safe operation context. Do not log the full response body.

## Pre-change / post-change checks (Flutter)

Before committing any change under `lib/` or `test/`:

1. `flutter analyze` — zero issues.
2. `flutter test` — all passing; if you touched a service or data model with existing coverage in `test/services/` or `test/data/`, its tests must still pass, and a behavior change needs a matching test update, not just a passing run.
3. If you touched a page's visual layout, loading state, or navigation flow, manually run the app (`flutter run --dart-define-from-file=dart_defines/dev.json`) and exercise the changed screen. Automated coverage includes services, data models, providers/retry policy, several pages, and shared widgets, but render coverage is still incomplete (see [Migration debt register](#migration-debt-register-flutter) item 5), so analyzer + unit tests alone do not catch every UI regression.
4. If you added or changed a visual object, record the repository-wide search used to find existing Widgets and list every affected caller. Confirm that the result reuses the canonical Widget and does not introduce a near-duplicate.
5. A rename of a public method/class (service, provider, or otherwise) requires grepping the whole `lib/`/`test/` tree for the old name before considering the change done.

---

# Shared contract (both stacks)

- **Response envelope**: the backend's own REST endpoints return `BaseResponse[T]` (`success`, `message`, `data`, `error_code`). Direct third-party calls (e.g. Open-Meteo) and signed-URL PUTs to GCS are outside this envelope. For backend calls, `BaseService.decodeMap` handles 401 separately through the auth flow; for other non-2xx responses it safely parses `error_code`/`message` when present and throws `ApiException`, while malformed/non-JSON error bodies fall back without rethrowing parsing detail. On success it validates that the body is a JSON object, and individual services destructure `envelope['data']`. `data` is load-bearing at essentially every call site. Cross-cutting user-facing mappings for selected backend codes live in `api_error_text.dart`; feature-specific paths such as `MatchLookException` / `ClosetAnalysisException` may keep specialized decoding. Backend `message` is diagnostic/contextual data, not default UI copy. `success` is not currently relied on for ordinary branching, but it remains part of the backend contract. Do not change the envelope shape from either side without coordinating both repos in the same change.
- **Auth expiry**: backend unrecoverable 401 → Flutter's `AuthExpiredException` — see [Error handling (UI)](#error-handling-ui) above for the full flow, including the silent-refresh-and-retry step that happens first. Any backend change to when/how 401 is returned must be checked against this mapping.
- **Error codes**: the backend's `ErrorCode` enum is the intended full taxonomy; Flutter does not re-declare it as a parallel enum. Cross-cutting mappings belong in `api_error_text.dart`; a feature-specific code may be handled by that feature's established typed exception path. Do not duplicate the same `switch (errorCode)` across pages, and never display the backend `message` merely because a code is unknown — fall back to localized operation-specific copy. Note the backend's own 500 catch-all currently emits a literal `"INTERNAL_SERVER_ERROR"` that isn't itself an `ErrorCode` member — treat that value as a special case if it ever needs matching, not proof the enum is incomplete elsewhere.
