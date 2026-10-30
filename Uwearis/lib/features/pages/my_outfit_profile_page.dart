import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/auto_save_controller.dart';
import '../../core/utils/base_model_generation_mixin.dart';
import '../../data/profile_data.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/generated_image_card.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/auto_save_prompts.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import 'reference_photos_page.dart';

/// Re-signs the base model's URL; it's cached in [profileProvider] for the
/// whole session and outlives its signed-URL expiry.
final fetchFreshBaseModelUrlProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () => ProfileService().getBaseModel(),
);

/// The virtual model and the temperature offset: one entry point, but
/// separate data, saving and errors — neither section triggers the other.
class MyOutfitProfilePage extends ConsumerStatefulWidget {
  const MyOutfitProfilePage({super.key});

  @override
  ConsumerState<MyOutfitProfilePage> createState() =>
      _MyOutfitProfilePageState();
}

class _MyOutfitProfilePageState extends ConsumerState<MyOutfitProfilePage>
    with BaseModelGenerationMixin {
  static const double _previewAspectRatio = 3 / 4;

  // The backend field is write-only (not in /users/me), so the last saved
  // value is cached locally.
  static const _temperatureOffsetKey = 'temperature_offset';
  static const _minTemperatureOffset = -5;
  static const _maxTemperatureOffset = 5;

  int _temperatureOffset = 0;
  late final AutoSaveController _temperatureAutoSave = AutoSaveController(
    onSave: _saveTemperatureOffset,
    onError: (e) => showAutoSaveErrorDialog(
      context,
      _temperatureAutoSave,
      e,
      fallback: _l10n.profileSaveFailed,
    ),
  );
  bool _leaving = false;
  bool _savingBeforeLeave = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _loadTemperatureOffset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(profileProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException && mounted) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  @override
  void dispose() {
    _temperatureAutoSave.dispose();
    super.dispose();
  }

  Future<void> _loadTemperatureOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_temperatureOffsetKey);
    // A tap before the cache loads wins over the cached value.
    if (saved == null || !mounted || _temperatureAutoSave.hasPendingChanges) {
      return;
    }
    setState(() => _temperatureOffset = saved);
  }

  String _temperatureOffsetLabel(int offset) =>
      '${offset > 0 ? '+' : ''}$offset°C';

  void _stepTemperatureOffset(int delta) {
    setState(() => _temperatureOffset += delta);
    _temperatureAutoSave.requestSave();
  }

  /// Only touches the offset — no model regenerate, no outfit replan.
  Future<void> _saveTemperatureOffset() async {
    final offset = _temperatureOffset;
    await ProfileService().updateMyProfile(temperatureOffsetC: offset);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_temperatureOffsetKey, offset);
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final canLeave = await confirmLeaveAfterAutoSave(
        context,
        _temperatureAutoSave,
        onFlushingChanged: (saving) =>
            setState(() => _savingBeforeLeave = saving),
      );
      if (canLeave && mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  void _openReferencePhotos() {
    // ReferencePhotosPage commits to profileProvider itself, so the preview
    // here is already current on return.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReferencePhotosPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _temperatureAutoSave,
      builder: (context, child) => PopScope(
        canPop: !_temperatureAutoSave.hasPendingChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: child!,
      ),
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: AppColors.pageBackground,
            appBar: AppToolBar(
              title: _l10n.myOutfitProfileTitle,
              onBack: _leave,
            ),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _buildVirtualModelCard(),
                const SizedBox(height: AppDimens.sectionSpacing),
                _buildTemperatureCard(),
              ],
            ),
          ),
          if (generatingBaseModel)
            Positioned.fill(
              child: LoadingOverlay(label: _l10n.generatingEllipsis),
            ),
          if (_savingBeforeLeave)
            Positioned.fill(child: LoadingOverlay(label: _l10n.savingEllipsis)),
        ],
      ),
    );
  }

  Widget _buildVirtualModelCard() {
    final profile = ref.watch(profileProvider);
    final data = profile.value;
    return AppCardShell(
      title: _l10n.virtualModelSectionTitle,
      subtitle: _l10n.virtualModelSectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data != null)
            _buildBaseModelPreview(data)
          else if (profile.hasError)
            ErrorStateWidget(
              error: profile.error!,
              onRetry: () => ref.read(profileProvider.notifier).refresh(),
            )
          else
            const SizedBox(height: 140, child: Center(child: AppSpinner())),
        ],
      ),
    );
  }

  /// Gated on the body photo only: the backend requires it, while the face
  /// photo is an optional identity input.
  Widget _buildBaseModelPreview(ProfileData data) {
    final hasBodyRef = data.hasBodyReference;
    final baseModelUrl = ProfileData.isRealPhotoUrl(data.baseModelUrl)
        ? data.baseModelUrl
        : null;
    final canGenerate = hasBodyRef && !baseModelBusy;
    return GeneratedImageCard(
      imageUrl: baseModelUrl,
      hasAssignment: true,
      // No isLoading: build()'s full-screen LoadingOverlay covers it.
      cacheKey: baseModelImageCacheKey(),
      imageFit: BoxFit.contain,
      imageAlignment: Alignment.center,
      aspectRatio: _previewAspectRatio,
      onRefreshUrl: () => ref.read(fetchFreshBaseModelUrlProvider)(),
      onUrlRefreshed: (oldUrl, freshUrl) => ref
          .read(profileProvider.notifier)
          .setBaseModelUrlIfCurrent(oldUrl, freshUrl),
      onGenerate: generateBaseModel,
      generateEnabled: canGenerate,
      generateDisabledMessage: hasBodyRef
          ? null
          : _l10n.virtualModelGenerateRequiresBodyRefHint,
      generateLabel: _l10n.virtualModelGenerateAction,
      cornerAction: AccentPillButton(
        key: const ValueKey('editPhotosAction'),
        label: _l10n.edit,
        onPressed: _openReferencePhotos,
      ),
    );
  }

  static const double _stepperLabelGap = 8;
  static final TextStyle _stepperLabelStyle = AppTextStyle.medium14.copyWith(
    color: AppColors.textSecondary,
  );

  double _measureStepperLabel(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _stepperLabelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return width;
  }

  Widget _buildTemperatureCard() {
    final offset = _temperatureOffset;
    return AppCardShell(
      title: _l10n.temperatureAdjustmentTitle,
      subtitle: _l10n.temperatureAdjustmentDescription,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same − / + spread as Create Outfit's half-width temperature tile.
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final minStepperWidth = NumberStepper.tileWidthFor(
                context,
                _temperatureOffsetLabel(_maxTemperatureOffset),
              );
              final stepper = NumberStepper(
                variant: NumberStepperVariant.tile,
                valueLabel: _temperatureOffsetLabel(offset),
                onDecrement: offset > _minTemperatureOffset
                    ? () => _stepTemperatureOffset(-1)
                    : null,
                onIncrement: offset < _maxTemperatureOffset
                    ? () => _stepTemperatureOffset(1)
                    : null,
              );
              final warmer = Text(
                _l10n.temperatureAdjustmentWarmer,
                style: _stepperLabelStyle,
              );
              final lighter = Text(
                _l10n.temperatureAdjustmentLighter,
                style: _stepperLabelStyle,
              );
              // Equal side columns keep the value centered under the title.
              final labelWidth = math.max(
                _measureStepperLabel(
                  context,
                  _l10n.temperatureAdjustmentWarmer,
                ),
                _measureStepperLabel(
                  context,
                  _l10n.temperatureAdjustmentLighter,
                ),
              );
              final sideWidth = labelWidth + _stepperLabelGap;
              if (maxWidth - 2 * sideWidth >= minStepperWidth) {
                final stepperWidth = math.min(
                  maxWidth - 2 * sideWidth,
                  math.max(maxWidth / 2, minStepperWidth),
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: warmer,
                      ),
                    ),
                    const SizedBox(width: _stepperLabelGap),
                    SizedBox(width: stepperWidth, child: stepper),
                    const SizedBox(width: _stepperLabelGap),
                    SizedBox(width: labelWidth, child: lighter),
                  ],
                );
              }
              // Under the stepper, wide enough that neither label breaks.
              final stepperWidth = math.min(
                maxWidth,
                [
                  maxWidth / 2,
                  minStepperWidth,
                  2 * labelWidth + _stepperLabelGap,
                ].reduce(math.max),
              );
              return Center(
                child: SizedBox(
                  width: stepperWidth,
                  child: Column(
                    children: [
                      stepper,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(child: warmer),
                          const SizedBox(width: _stepperLabelGap),
                          Flexible(
                            child: Text(
                              _l10n.temperatureAdjustmentLighter,
                              style: _stepperLabelStyle,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
