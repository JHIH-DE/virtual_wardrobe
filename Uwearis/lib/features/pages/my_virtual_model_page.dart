import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../core/utils/reference_photo_download.dart';
import '../../data/image_edit_result.dart';
import '../../data/profile_data.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/generated_image_card.dart';
import '../widgets/common/images/app_image.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import 'camera_capture_page.dart';
import 'image_editor_page.dart';

/// Face and body reference photos go through the exact same
/// prepare-original → edit → upload → verify → commit flow (see
/// [_MyVirtualModelPageState._changePhoto]/[_MyVirtualModelPageState
/// ._uploadPhoto]) — this and [_PhotoSlot] let the page implement that
/// flow once, parameterized by which photo, instead of two near-identical
/// copies.
enum ReferencePhotoKind { face, body }

// ---- Injectable seams for the prepare → upload → verify pipeline ----
//
// Every real network/decoding step this page depends on — downloading the
// committed photo, re-fetching a fresh signed URL, uploading, and verifying
// a newly-uploaded URL actually loads — is exposed as a plain Riverpod
// `Provider` rather than being called directly (`ProfileService()`,
// `precacheImage(CachedNetworkImageProvider(...))`, ...). Production wiring
// (the default below) is unchanged; widget tests override these with fakes
// via `ProviderScope(overrides: [...])` so they can exercise the upload
// commit/rollback logic without a real network round trip and without a
// real `CachedNetworkImage` fetch ever running (that goes through
// flutter_cache_manager, which needs a sqflite database factory this test
// suite doesn't set up — see my_virtual_model_page_test.dart's own notes).

typedef DownloadReferencePhotoOriginal =
    Future<String?> Function({
      required String url,
      required String fileNamePrefix,
      required Future<String?> Function() onRefreshUrl,
      required void Function(String freshUrl) onUrlRefreshed,
    });

/// Defaults to the real [downloadReferencePhotoOriginal] (plain
/// `package:http`, already fakeable via `http.runWithClient` on its own —
/// exposed as a provider too so every step of this pipeline is overridden
/// the same way in tests).
final downloadReferencePhotoOriginalProvider =
    Provider<DownloadReferencePhotoOriginal>(
      (ref) => downloadReferencePhotoOriginal,
    );

typedef FetchFreshReferenceUrl = Future<String?> Function(ReferencePhotoKind kind);

final fetchFreshReferenceUrlProvider = Provider<FetchFreshReferenceUrl>(
  (ref) => (kind) => kind == ReferencePhotoKind.face
      ? ProfileService().getFaceReference()
      : ProfileService().getBodyRef(),
);

typedef UploadReferencePhoto =
    Future<String> Function(ReferencePhotoKind kind, String localPath);

final uploadReferencePhotoProvider = Provider<UploadReferencePhoto>(
  (ref) => (kind, localPath) => kind == ReferencePhotoKind.face
      ? ProfileService().uploadFaceRef(localPath)
      : ProfileService().uploadBodyRef(localPath),
);

/// Confirms a freshly-uploaded signed URL is actually fetchable/decodable
/// before the page commits to it — production does this via Flutter's real
/// image cache; a test fake can just check the URL against whatever it
/// mocked, with no real image decode involved.
typedef VerifyReferencePhotoLoads =
    Future<void> Function(BuildContext context, String url);

final verifyReferencePhotoLoadsProvider = Provider<VerifyReferencePhotoLoads>(
  (ref) => (context, url) => precacheImage(CachedNetworkImageProvider(url), context),
);

typedef GenerateBaseModel = Future<String> Function();

final generateBaseModelProvider = Provider<GenerateBaseModel>(
  (ref) => () => ProfileService().generateBaseModel(),
);

/// Per-photo UI-only state, kept separate from [profileProvider] (the sole
/// authority for the *committed*, backend-confirmed signed URL) and from
/// any pending local file, which is never stored in State at all — a
/// picked/cropped photo lives only as a local variable for the duration of
/// its own upload attempt (see [_MyVirtualModelPageState._uploadPhoto]), so
/// there's nothing here for a failed/abandoned upload to leave behind.
class _PhotoSlot {
  /// True for the whole prepare-original → edit → upload round trip for
  /// this photo — guards re-entry (see [_MyVirtualModelPageState._changePhoto])
  /// and disables this card's own tap target while true.
  bool busy = false;

  /// True only while the actual upload (init-upload → PUT → complete →
  /// load-verify) is in flight — drives this card's uploading overlay.
  bool uploading = false;

  /// Set when the *image widget* couldn't load the current signed URL (its
  /// GCS object is gone — see [AppImage.onLoadError]/
  /// [RefreshableNetworkImage.onLoadError]) — a per-photo UI concern, not an
  /// API/provider error. Never set from a `catch` block; never affects
  /// `profileProvider`/the other reference photo. Cleared whenever a fresh
  /// URL is loaded (profile reload) or a new photo is uploaded.
  bool loadFailed = false;
}

class MyVirtualModelPage extends ConsumerStatefulWidget {
  const MyVirtualModelPage({super.key});

  @override
  ConsumerState<MyVirtualModelPage> createState() => _MyVirtualModelPageState();
}

class _MyVirtualModelPageState extends ConsumerState<MyVirtualModelPage> {
  // There's only one base model per user (unlike outfitImageCacheKey, no
  // per-entity id needed) — see ImageCacheBust.bump's own call site below
  // for why a regenerate must change this key, not just the URL.
  static const _baseModelCacheKey = 'base_model';

  // Loading state for the initial profile fetch — gates the reference-photo
  // cards' and the base-model action's own tap targets while in flight.
  bool _loading = false;

  // profileProvider is the sole authority for each photo's *committed*
  // signed URL (read via ref.watch in build) — these are the only
  // page-local fields, one per photo, and hold nothing that duplicates it.
  final _faceSlot = _PhotoSlot();
  final _bodySlot = _PhotoSlot();

  // Re-entrancy guard for _generateBaseModel — kept separate from _loading
  // and the photo slots' own flags since it guards a distinct backend call.
  bool _generatingBaseModel = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      // Shared with Account / Settings via profileProvider.
      await ref.read(profileProvider.future);
      if (!mounted) return;
      setState(() {
        _faceSlot.loadFailed = false;
        _bodySlot.loadFailed = false;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('MyVirtualModelPage._loadProfile failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.failedToLoad),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  _PhotoSlot _slotFor(ReferencePhotoKind kind) =>
      kind == ReferencePhotoKind.face ? _faceSlot : _bodySlot;

  String _titleFor(ReferencePhotoKind kind) =>
      kind == ReferencePhotoKind.face ? _l10n.facePhotoLabel : _l10n.fullBodyPhotoLabel;

  String? _committedUrlOf(ReferencePhotoKind kind, ProfileData? data) {
    if (data == null) return null;
    return kind == ReferencePhotoKind.face ? data.faceRefUrl : data.bodyRefUrl;
  }

  void _commitUrl(ReferencePhotoKind kind, String url) {
    if (kind == ReferencePhotoKind.face) {
      ref.read(profileProvider.notifier).setFaceRefUrl(url);
    } else {
      ref.read(profileProvider.notifier).setBodyRefUrl(url);
    }
  }

  /// Applies a self-healed signed URL (from [RefreshableNetworkImage]'s own
  /// self-heal, or from [downloadReferencePhotoOriginal]'s refresh-and-retry)
  /// only if [profileProvider]'s committed URL is still [expectedCurrent] —
  /// the value that refresh believed was stale. A refresh that was already
  /// in flight when a separate, newer upload committed its own URL must not
  /// clobber that newer commit once the stale refresh finally resolves (see
  /// [ProfileNotifier.setBodyRefUrlIfCurrent]/[setFaceRefUrlIfCurrent]).
  void _commitUrlIfCurrent(
    ReferencePhotoKind kind,
    String expectedCurrent,
    String freshUrl,
  ) {
    if (kind == ReferencePhotoKind.face) {
      ref
          .read(profileProvider.notifier)
          .setFaceRefUrlIfCurrent(expectedCurrent, freshUrl);
    } else {
      ref
          .read(profileProvider.notifier)
          .setBodyRefUrlIfCurrent(expectedCurrent, freshUrl);
    }
  }

  /// Best-effort delete of a local temp file this page created (a
  /// downloaded original, or a cropped pending-upload output) once it's no
  /// longer needed — regardless of whether the flow it belonged to
  /// succeeded or failed. Never lets a cleanup failure surface to the user;
  /// this is housekeeping, not part of the actual result.
  Future<void> _deleteTempFileQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugLog('MyVirtualModelPage: failed to clean up temp file: $e');
    }
  }

  /// Downloads the *committed* photo (from [profileProvider], via
  /// [_committedUrlOf]) to a local file — refreshing and re-syncing the
  /// signed URL through [downloadReferencePhotoOriginalProvider] if it's
  /// already expired — so [ImageEditorPage] only ever receives a
  /// definitely-valid local source, never a signed URL that might already
  /// be stale.
  Future<String?> _prepareLocalOriginal(ReferencePhotoKind kind, String url) {
    return ref.read(downloadReferencePhotoOriginalProvider)(
      url: url,
      fileNamePrefix: '${kind.name}_ref_original',
      onRefreshUrl: () => ref.read(fetchFreshReferenceUrlProvider)(kind),
      // Compare-and-set: only applies if `url` (what this refresh started
      // from) is still profileProvider's committed URL — see
      // _commitUrlIfCurrent's own doc.
      onUrlRefreshed: (fresh) => _commitUrlIfCurrent(kind, url, fresh),
    );
  }

  /// The one change-photo flow shared by face and body reference photos —
  /// see [ReferencePhotoKind]'s own doc for why this replaces two near-identical
  /// copies. [_PhotoSlot.busy] is set synchronously before the first
  /// `await` and only cleared in `finally`, covering prepare → edit →
  /// upload as one re-entrancy-guarded unit (see CLAUDE.md's "Guarding
  /// costly / mutating actions against double-invocation").
  Future<void> _changePhoto(ReferencePhotoKind kind) async {
    final slot = _slotFor(kind);
    if (slot.busy) return;
    setState(() => slot.busy = true);
    String? localOriginalPath;
    try {
      final data = ref.read(profileProvider).value;
      final committedUrl = _resolvedUrl(_committedUrlOf(kind, data));

      if (committedUrl != null) {
        try {
          localOriginalPath = await _prepareLocalOriginal(kind, committedUrl);
        } on AuthExpiredException {
          if (mounted) await AuthExpiredHandler.handle(context);
          return;
        } catch (e) {
          debugLog('MyVirtualModelPage._changePhoto($kind) prepare failed: $e');
        }
        if (localOriginalPath == null) {
          // Neither the committed URL nor a refreshed one could be
          // downloaded — stay on this page rather than open an editor with
          // nothing to show (see my_virtual_model_page's design brief: "原圖準備
          // 失敗時，不要進入空白的編輯頁，留在原頁顯示錯誤").
          if (mounted) {
            showErrorDialog(context, message: _l10n.photoProcessingFailed);
          }
          return;
        }
      }

      if (!mounted) return;
      final result = await Navigator.push<ImageEditResult?>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditorPage(
            title: _titleFor(kind),
            initialPath: localOriginalPath,
            aspectRatio: 3 / 4,
            cameraFrameRatio: CameraFrameRatio.portrait,
            // This reopens the already-saved photo — confirming with zero
            // changes would just re-upload an identical copy.
            requireChangeToConfirm: true,
          ),
        ),
      );
      if (result == null || !mounted) return;
      await _uploadPhoto(kind, result.imagePath);
    } finally {
      // The downloaded original (if any) has served its purpose the moment
      // ImageEditorPage has popped — confirmed (its own crop output is a
      // separate file, cleaned up in _uploadPhoto), cancelled, or replaced
      // via Retake/Album — nothing downstream ever reads it again.
      await _deleteTempFileQuietly(localOriginalPath);
      if (mounted) setState(() => slot.busy = false);
    }
  }

  /// The cropped local file from [ImageEditorPage] is only ever a *pending*
  /// upload candidate — it's never written to any [_PhotoSlot]/State field,
  /// so there is nothing for the card to optimistically show before this
  /// finishes. [_PhotoSlot.uploading] drives the card's uploading overlay;
  /// [profileProvider] (the committed photo) is only updated once every
  /// step below — upload, then load-verification of the new URL — has
  /// actually succeeded. Any failure leaves the committed photo, and
  /// [profileProvider], exactly as they were.
  Future<void> _uploadPhoto(ReferencePhotoKind kind, String localPath) async {
    final slot = _slotFor(kind);
    setState(() => slot.uploading = true);
    try {
      final url = await ref.read(uploadReferencePhotoProvider)(kind, localPath);
      if (!mounted) return;
      // Confirms the new photo is actually fetchable before committing the
      // UI to it — an upload whose signed URL doesn't load is treated the
      // same as any other upload failure (see the `catch` below), not
      // silently committed anyway.
      await ref.read(verifyReferencePhotoLoadsProvider)(context, url);
      if (!mounted) return;
      _commitUrl(kind, url);
      setState(() => slot.loadFailed = false);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('MyVirtualModelPage._uploadPhoto($kind) failed: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: apiErrorMessage(_l10n, e, fallback: _l10n.photoUploadFailed),
        );
      }
    } finally {
      // The pending file has served its purpose regardless of outcome —
      // see the class-level doc on _PhotoSlot for why nothing else ever
      // holds a reference to it.
      await _deleteTempFileQuietly(localPath);
      if (mounted) setState(() => slot.uploading = false);
    }
  }

  /// Manually (re-)triggers [ProfileService.generateBaseModel] — a
  /// destructive replace on the backend (it clears the previous base-model
  /// file), so this confirms first, same as [outfit_details_page]'s
  /// _regenerateImage. Guarded synchronously before the confirm dialog's
  /// own `await` so a double-tap can't queue two confirms.
  Future<void> _generateBaseModel() async {
    if (_generatingBaseModel) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.virtualModelGenerateConfirmTitle,
        body: _l10n.virtualModelGenerateConfirmBody,
        primaryLabel: _l10n.virtualModelGenerateAction,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _generatingBaseModel = true);
    var succeeded = false;
    try {
      final url = await ref.read(generateBaseModelProvider)();
      if (!mounted) return;
      ref.read(profileProvider.notifier).setBaseModelUrl(url);
      // A regenerate can return a freshly re-signed URL for the *same*
      // underlying GCS object flutter_cache_manager already has a disk
      // entry for under _baseModelCacheKey — without bumping, it serves
      // those stale cached bytes instead of the new render (same fix as
      // OutfitDetailsPage._regenerateImage's ImageCacheBust.bump call).
      ImageCacheBust.bump(_baseModelCacheKey);
      succeeded = true;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      if (!mounted) return;
      debugLog('MyVirtualModelPage._generateBaseModel failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.virtualModelGenerateFailed),
      );
    } finally {
      if (mounted) setState(() => _generatingBaseModel = false);
    }

    // Shown only after the loading overlay above is already gone — the
    // overlay and this confirmation must never be on screen together.
    if (succeeded && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: _l10n.virtualModelGenerateSuccessTitle,
          body: _l10n.virtualModelGenerateSuccessBody,
          primaryLabel: _l10n.ok,
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.myVirtualModelTitle);
  }

  @override
  Widget build(BuildContext context) {
    // The one ref.watch for both cards' committed photos — profileProvider
    // is the sole authority for them, so neither card keeps its own copy.
    final profileData = ref.watch(profileProvider).value;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _l10n.myVirtualModelDescription,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildReferenceCardFor(
                        ReferencePhotoKind.face,
                        profileData,
                      ),
                    ),
                    const SizedBox(width: AppDimens.cardSpacing),
                    Expanded(
                      child: _buildReferenceCardFor(
                        ReferencePhotoKind.body,
                        profileData,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                _buildBaseModelCard(profileData),
              ],
            ),
          ),
        ),
        if (_generatingBaseModel)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingEllipsis),
          ),
      ],
    );
  }

  /// Body-reference is required by the backend; face-reference is only used
  /// as an optional face-identity input (see
  /// [ProfileService.generateBaseModel]'s own doc) — so the trigger is
  /// gated on the body photo alone, not both. Reuses [GeneratedImageCard]
  /// (the same "image, or a Generate button in an empty bordered box" shape
  /// Trip Details uses for a day's outfit) rather than a page-local
  /// look-alike — the corner regenerate badge doubles as this endpoint's own
  /// generate-or-regenerate action once a base model already exists.
  Widget _buildBaseModelCard(ProfileData? data) {
    final hasBodyRef = _resolvedUrl(data?.bodyRefUrl) != null;
    final baseModelUrl = _resolvedUrl(data?.baseModelUrl);
    final canGenerate = hasBodyRef && !_loading && !_generatingBaseModel;
    return AppCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(_l10n.virtualModelSectionTitle),
          const SizedBox(height: 6),
          Text(
            _l10n.virtualModelSectionSubtitle,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          GeneratedImageCard(
            imageUrl: baseModelUrl,
            hasAssignment: true,
            // The full-screen LoadingOverlay in build() already covers this
            // card while generating — this widget's own internal loading
            // treatment on top of the image would be redundant (and hidden
            // underneath that overlay anyway).
            cacheKey:
                '$_baseModelCacheKey-v${ImageCacheBust.versionOf(_baseModelCacheKey)}',
            // contain (instead of the default cover+topCenter) keeps the
            // whole photo visible rather than cropping it — the default 3:4
            // frame already matches it closely enough that contain leaves no
            // visible letterboxing.
            imageFit: BoxFit.contain,
            imageAlignment: Alignment.center,
            onGenerate: _generateBaseModel,
            generateEnabled: canGenerate,
            generateDisabledMessage: hasBodyRef
                ? null
                : _l10n.virtualModelGenerateRequiresBodyRefHint,
            generateLabel: _l10n.virtualModelGenerateAction,
            onRegenerate: canGenerate ? _generateBaseModel : null,
          ),
        ],
      ),
    );
  }

  /// One card shape for both Face and Body reference tiles, placed
  /// side-by-side by [build]. [photo] sits on top (dominant); [title] and
  /// [action] stack below it. [subtitle] is only passed for the load-failed
  /// state's actionable copy — the normal state has no descriptive subtitle.
  /// [onTap] only makes [action] itself tappable — the rest of the card
  /// (title, photo) is inert, so a stray tap elsewhere doesn't accidentally
  /// open the photo picker.
  Widget _buildReferenceCard({
    required String title,
    required Widget photo,
    String? subtitle,
    required Widget action,
    required VoidCallback? onTap,
    Key? actionKey,
  }) {
    Widget tappableAction = action;
    if (onTap != null) {
      tappableAction = InkWell(
        key: actionKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          // Pads the ~20px-tall "Add/Update photo" row out to a
          // minTouchTarget hit area — the photo it opens feeds a paid AI
          // render.
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: tappableAction,
        ),
      );
    }

    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo,
          const SizedBox(height: 10),
          SectionTitle(title),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          // tappableAction carries its own vertical padding when
          // interactive (see above), so no fixed gap here.
          const SizedBox(height: 2),
          tappableAction,
        ],
      ),
    );
  }

  Widget _buildPhotoAction(String? url) => _buildActionLabel(
    url != null ? _l10n.updatePhotoAction : _l10n.addPhotoAction,
  );

  Widget _buildActionLabel(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyle.semibold14.copyWith(color: AppColors.accent),
        ),
        Image.asset(
          'assets/images/page_arrow_right.png',
          width: 18,
          height: 18,
          color: AppColors.accent,
          colorBlendMode: BlendMode.srcIn,
        ),
      ],
    );
  }

  Widget _buildPhotoLeading(
    ReferencePhotoKind kind,
    String? url, {
    required IconData placeholder,
  }) {
    final slot = _slotFor(kind);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // Backs the letterboxed edges BoxFit.contain leaves when the
          // photo's own aspect ratio doesn't match this tile's 3:4 — cover
          // used to crop those edges away instead, which was cutting real
          // content off a full-body photo.
          color: AppColors.placeholderSurface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              url != null
                  ? AppImage(
                      url: url,
                      onRefreshUrl: () =>
                          ref.read(fetchFreshReferenceUrlProvider)(kind),
                      // Compare-and-set — see _commitUrlIfCurrent's own doc.
                      onUrlRefreshed: (oldUrl, freshUrl) =>
                          _commitUrlIfCurrent(kind, oldUrl, freshUrl),
                      onLoadError: () {
                        if (mounted) setState(() => slot.loadFailed = true);
                      },
                      fit: BoxFit.contain,
                    )
                  : Center(
                      child: Icon(
                        placeholder,
                        color: AppColors.borderStrong,
                        size: 28,
                      ),
                    ),
              if (slot.uploading) _buildUploadingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// Shown over the tile in place of switching it to the pending local
  /// photo (see [_uploadPhoto]'s own doc) — the card keeps showing the
  /// committed photo/placeholder underneath for the whole upload.
  Widget _buildUploadingOverlay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: AppColors.scrimBackdrop,
        child: const Center(
          child: AppSpinner(size: 24, color: AppColors.textOnPrimary),
        ),
      ),
    );
  }

  Widget _buildReferenceCardFor(ReferencePhotoKind kind, ProfileData? data) {
    final slot = _slotFor(kind);
    final failed = slot.loadFailed;
    final url = failed ? null : _resolvedUrl(_committedUrlOf(kind, data));
    final isFace = kind == ReferencePhotoKind.face;
    return _buildReferenceCard(
      title: failed
          ? (isFace
                ? _l10n.facePhotoLoadFailedTitle
                : _l10n.fullBodyPhotoLoadFailedTitle)
          : _titleFor(kind),
      actionKey: ValueKey('updatePhotoAction-${kind.name}'),
      onTap: (_loading || slot.busy) ? null : () => _changePhoto(kind),
      photo: _buildPhotoLeading(
        kind,
        url,
        placeholder: failed
            ? Icons.error_outline
            : (isFace ? Icons.face_outlined : Icons.accessibility_new_outlined),
      ),
      subtitle: failed ? _l10n.photoLoadFailedSubtitle : null,
      action: failed
          ? _buildActionLabel(_l10n.reuploadPhotoAction)
          : _buildPhotoAction(url),
    );
  }

  /// The backend's OpenAPI schema example ("string") occasionally leaks
  /// through as a literal placeholder value instead of a real URL/null —
  /// treat it the same as "no photo set".
  String? _resolvedUrl(String? url) =>
      (url == null || url.isEmpty || url == 'string') ? null : url;
}
