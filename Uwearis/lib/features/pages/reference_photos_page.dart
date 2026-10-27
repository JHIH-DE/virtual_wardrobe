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
import '../../core/utils/base_model_generation_mixin.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/reference_photo_download.dart';
import '../../data/image_edit_result.dart';
import '../../data/profile_data.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/images/app_image.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import 'camera_capture_page.dart';
import 'image_editor_page.dart';

/// Which reference photo a shared prepare → edit → upload → verify → commit
/// flow is acting on.
enum ReferencePhotoKind { face, body }

// Test seams: each network/decode step is a Provider so widget tests can
// override it. A real CachedNetworkImage fetch needs a sqflite database
// factory the test suite doesn't set up.

typedef DownloadReferencePhotoOriginal =
    Future<String?> Function({
      required String url,
      required String fileNamePrefix,
      required Future<String?> Function() onRefreshUrl,
      required void Function(String freshUrl) onUrlRefreshed,
    });

final downloadReferencePhotoOriginalProvider =
    Provider<DownloadReferencePhotoOriginal>(
      (ref) => downloadReferencePhotoOriginal,
    );

typedef FetchFreshReferenceUrl =
    Future<String?> Function(ReferencePhotoKind kind);

final fetchFreshReferenceUrlProvider = Provider<FetchFreshReferenceUrl>(
  (ref) =>
      (kind) => kind == ReferencePhotoKind.face
      ? ProfileService().getFaceReference()
      : ProfileService().getBodyRef(),
);

typedef UploadReferencePhoto =
    Future<String> Function(ReferencePhotoKind kind, String localPath);

final uploadReferencePhotoProvider = Provider<UploadReferencePhoto>(
  (ref) =>
      (kind, localPath) => kind == ReferencePhotoKind.face
      ? ProfileService().uploadFaceRef(localPath)
      : ProfileService().uploadBodyRef(localPath),
);

/// Confirms a freshly-uploaded signed URL actually loads before the page
/// commits to it.
typedef VerifyReferencePhotoLoads =
    Future<void> Function(BuildContext context, String url);

final verifyReferencePhotoLoadsProvider = Provider<VerifyReferencePhotoLoads>(
  (ref) =>
      (context, url) => precacheImage(CachedNetworkImageProvider(url), context),
);

/// Per-photo UI-only state. The committed URL lives only in
/// [profileProvider]; a pending upload file is never stored in State.
class _PhotoSlot {
  /// The whole prepare → edit → upload round trip; guards re-entry.
  bool busy = false;

  /// Only the upload + load-verify step; drives the uploading overlay.
  bool uploading = false;

  /// The image widget couldn't load the current URL (GCS object gone).
  /// Card-local only — never fails [profileProvider] or the other photo.
  bool loadFailed = false;
}

/// The face and full-body reference photos behind the virtual model, opened
/// from the Edit button on My Outfit Profile's model preview.
class ReferencePhotosPage extends ConsumerStatefulWidget {
  const ReferencePhotosPage({super.key});

  @override
  ConsumerState<ReferencePhotosPage> createState() =>
      _ReferencePhotosPageState();
}

class _ReferencePhotosPageState extends ConsumerState<ReferencePhotosPage>
    with BaseModelGenerationMixin {
  bool _loading = false;

  final _faceSlot = _PhotoSlot();
  final _bodySlot = _PhotoSlot();

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
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
      debugLog('ReferencePhotosPage._loadProfile failed: $e');
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

  String _titleFor(ReferencePhotoKind kind) => kind == ReferencePhotoKind.face
      ? _l10n.facePhotoLabel
      : _l10n.fullBodyPhotoLabel;

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

  /// Compare-and-set for a refreshed signed URL: applies only if the
  /// committed URL is still [expectedCurrent], so a slow refresh can't
  /// clobber a newer upload's commit.
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

  /// Best-effort temp-file cleanup; failures are only logged.
  Future<void> _deleteTempFileQuietly(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugLog('ReferencePhotosPage: failed to clean up temp file: $e');
    }
  }

  /// Downloads the committed photo to a local file (refreshing an expired
  /// signed URL) so [ImageEditorPage] never gets a stale URL.
  Future<String?> _prepareLocalOriginal(ReferencePhotoKind kind, String url) {
    return ref.read(downloadReferencePhotoOriginalProvider)(
      url: url,
      fileNamePrefix: '${kind.name}_ref_original',
      onRefreshUrl: () => ref.read(fetchFreshReferenceUrlProvider)(kind),
      onUrlRefreshed: (fresh) => _commitUrlIfCurrent(kind, url, fresh),
    );
  }

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
          debugLog(
            'ReferencePhotosPage._changePhoto($kind) prepare failed: $e',
          );
        }
        if (localOriginalPath == null) {
          // Stay here rather than open an editor with nothing to show.
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
            // Confirming with zero changes would re-upload an identical copy.
            requireChangeToConfirm: true,
          ),
        ),
      );
      if (result == null || !mounted) return;
      await _uploadPhoto(kind, result.imagePath);
    } finally {
      // The editor's crop output is a separate file, cleaned up in _uploadPhoto.
      await _deleteTempFileQuietly(localOriginalPath);
      if (mounted) setState(() => slot.busy = false);
    }
  }

  /// Commits to [profileProvider] only after the upload and a load-check of
  /// the new URL both succeed; any failure leaves the committed photo as is.
  Future<void> _uploadPhoto(ReferencePhotoKind kind, String localPath) async {
    final slot = _slotFor(kind);
    setState(() => slot.uploading = true);
    try {
      final url = await ref.read(uploadReferencePhotoProvider)(kind, localPath);
      if (!mounted) return;
      await ref.read(verifyReferencePhotoLoadsProvider)(context, url);
      if (!mounted) return;
      _commitUrl(kind, url);
      setState(() => slot.loadFailed = false);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('ReferencePhotosPage._uploadPhoto($kind) failed: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: apiErrorMessage(_l10n, e, fallback: _l10n.photoUploadFailed),
        );
      }
    } finally {
      await _deleteTempFileQuietly(localPath);
      if (mounted) setState(() => slot.uploading = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.edit);
  }

  /// Needs a full-body photo that's actually loading, and no photo change
  /// in progress — a render mid-upload would use the old photo.
  bool _canGenerate(ProfileData? data) =>
      data != null &&
      data.hasBodyReference &&
      !_bodySlot.loadFailed &&
      !_loading &&
      !_faceSlot.busy &&
      !_bodySlot.busy &&
      !baseModelBusy;

  /// Straight back to My Outfit Profile, where the new model is shown.
  Future<void> _generateNewModel() async {
    // Tapping this page's dedicated button is the confirmation.
    final succeeded = await generateBaseModel(confirm: false);
    if (succeeded && mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profileData = ref.watch(profileProvider).value;
    final showsGenerate = _canGenerate(profileData);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          bottomNavigationBar: BottomActionButton(
            key: const ValueKey('generateNewModelAction'),
            label: _l10n.virtualModelGenerateNewAction,
            enabled: showsGenerate,
            onPressed: _generateNewModel,
          ),
          body: Builder(
            builder: (bodyContext) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                showsGenerate
                    ? BottomActionButton.scrollClearance(bodyContext)
                    : 16 + MediaQuery.paddingOf(context).bottom,
              ),
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
                ],
              ),
            ),
          ),
        ),
        if (generatingBaseModel)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingEllipsis),
          ),
      ],
    );
  }

  /// Only the [actionLabel] pill is tappable, so a stray tap on the photo
  /// doesn't open the picker; a null [onTap] disables it. [subtitle] is only
  /// used in the load-failed state.
  Widget _buildReferenceCard({
    required String title,
    required Widget photo,
    String? subtitle,
    required String actionLabel,
    required VoidCallback? onTap,
    Key? actionKey,
  }) {
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
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: AccentPillButton(
              key: actionKey,
              label: actionLabel,
              enabled: onTap != null,
              onPressed: onTap,
            ),
          ),
        ],
      ),
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
          // Fills the letterbox edges: contain, so a full-body photo isn't cropped.
          color: AppColors.placeholderSurface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              url != null
                  ? AppImage(
                      url: url,
                      onRefreshUrl: () =>
                          ref.read(fetchFreshReferenceUrlProvider)(kind),
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

  /// The committed photo stays visible underneath during the upload.
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
      onTap: (_loading || slot.busy || baseModelBusy)
          ? null
          : () => _changePhoto(kind),
      photo: _buildPhotoLeading(
        kind,
        url,
        placeholder: failed
            ? Icons.error_outline
            : (isFace ? Icons.face_outlined : Icons.accessibility_new_outlined),
      ),
      subtitle: failed ? _l10n.photoLoadFailedSubtitle : null,
      actionLabel: failed
          ? _l10n.reuploadPhotoAction
          : (url != null ? _l10n.edit : _l10n.addPhotoAction),
    );
  }

  /// The backend's OpenAPI example value "string" sometimes leaks through as
  /// a URL; treat it as "no photo".
  String? _resolvedUrl(String? url) =>
      (url == null || url.isEmpty || url == 'string') ? null : url;
}
