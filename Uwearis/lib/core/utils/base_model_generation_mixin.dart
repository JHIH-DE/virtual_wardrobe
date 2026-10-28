import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/widgets/common/overlays/ai_consent_dialog.dart';
import '../../features/widgets/common/overlays/app_dialog.dart';
import '../../features/widgets/common/overlays/error_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/profile_provider.dart';
import '../services/auth_handler.dart';
import '../services/profile_service.dart';
import 'api_error_text.dart';
import 'debug_log.dart';
import 'image_cache_bust.dart';

typedef GenerateBaseModel = Future<String> Function();

/// Test seam for the AI render.
final generateBaseModelProvider = Provider<GenerateBaseModel>(
  (ref) =>
      () => ProfileService().generateBaseModel(),
);

// One base model per user, so no per-entity id.
const _baseModelCacheKey = 'base_model';

/// Bumped by every successful generation: a regenerate can overwrite the
/// same GCS object, and the disk cache would otherwise serve the old render.
String baseModelImageCacheKey() =>
    '$_baseModelCacheKey-v${ImageCacheBust.versionOf(_baseModelCacheKey)}';

/// The (confirm →) render → commit flow behind every "generate virtual model"
/// trigger (My Outfit Profile's preview, the reference photos page's bottom
/// button).
///
/// [baseModelBusy] is raised before the confirm dialog (the re-entrancy
/// guard — hide/disable triggers on it); [generatingBaseModel] only while the
/// render runs, so the host's `LoadingOverlay` never sits under the dialog.
mixin BaseModelGenerationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _baseModelBusy = false;
  bool generatingBaseModel = false;

  bool get baseModelBusy => _baseModelBusy;

  /// A successful run replaces the existing base model, so [confirm] asks
  /// first. Success is silent — the new image is the feedback. Returns
  /// whether it succeeded.
  Future<bool> generateBaseModel({bool confirm = true}) async {
    if (_baseModelBusy) return false;
    setState(() => _baseModelBusy = true);
    try {
      if (confirm) {
        final l10n = AppLocalizations.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AppDialog(
            title: l10n.virtualModelGenerateConfirmTitle,
            body: l10n.virtualModelGenerateConfirmBody,
            primaryLabel: l10n.virtualModelGenerateAction,
            onPrimary: () => Navigator.pop(ctx, true),
            secondaryLabel: l10n.cancel,
            onSecondary: () => Navigator.pop(ctx, false),
          ),
        );
        if (ok != true || !mounted) return false;
      }
      if (!await ensureAiConsent(context) || !mounted) return false;

      setState(() => generatingBaseModel = true);
      final url = await ref.read(generateBaseModelProvider)();
      if (!mounted) return false;
      ref.read(profileProvider.notifier).setBaseModelUrl(url);
      ImageCacheBust.bump(_baseModelCacheKey);
      return true;
    } on AuthExpiredException {
      if (!mounted) return false;
      await AuthExpiredHandler.handle(context);
      return false;
    } catch (e) {
      if (!mounted) return false;
      debugLog('generateBaseModel failed: $e');
      final l10n = AppLocalizations.of(context);
      showErrorDialog(
        context,
        message: apiErrorMessage(
          l10n,
          e,
          fallback: l10n.virtualModelGenerateFailed,
        ),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _baseModelBusy = false;
          generatingBaseModel = false;
        });
      }
    }
  }
}
