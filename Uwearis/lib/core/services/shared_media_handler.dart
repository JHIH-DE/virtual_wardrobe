import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../app/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../features/widgets/common/main_nav_bar.dart';
import '../../features/widgets/common/overlays/app_dialog.dart';
import '../../features/widgets/common/overlays/dialog_option_card.dart';
import '../../features/widgets/garment/garment_upload_helper.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/garments_provider.dart';
import 'auth_storage.dart';

/// Routes a photo shared from another app (Android `SEND` intent-filters,
/// iOS `ShareExtension` target) into Add Clothing or Match a Look. [listen]
/// covers both a cold start and a share while running.
class SharedMediaHandler {
  static StreamSubscription<List<SharedMediaFile>>? _subscription;

  static void listen(BuildContext context, WidgetRef ref) {
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (media.isEmpty || !context.mounted) return;
      // Read before reset(): some implementations clear this same list.
      final path = media.first.path;
      ReceiveSharingIntent.instance.reset();
      _handle(context, ref, path);
    });

    unawaited(_subscription?.cancel());
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen((
      media,
    ) {
      if (media.isNotEmpty && context.mounted) {
        _handle(context, ref, media.first.path);
      }
    });
  }

  /// Only the first photo of a multi-share is used — both flows take one.
  static Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String imagePath,
  ) async {
    // Logged out: dropped, with no resume-after-login.
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AppDialog(
        title: l10n.useSharedPhotoTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.useSharedPhotoSubtitle,
              textAlign: TextAlign.center,
              style: AppTextStyle.medium16,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DialogOptionCard(
                    variant: DialogOptionCardVariant.square,
                    icon: const Icon(
                      Icons.dry_cleaning_outlined,
                      color: AppColors.icon,
                      size: AppDimens.iconMediumSize,
                    ),
                    label: Text(
                      l10n.quickActionAddClothing,
                      style: AppTextStyle.bold16,
                    ),
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      GarmentUploadHelper.startAddClothingFlow(
                        context,
                        imagePath: imagePath,
                        onAdded: (g) {
                          ref.read(garmentsProvider.notifier).addGarment(g);
                          MainShellScope.of(context)?.selectTab(MainTab.closet);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DialogOptionCard(
                    variant: DialogOptionCardVariant.square,
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.icon,
                      size: AppDimens.iconMediumSize,
                    ),
                    label: Text(
                      l10n.matchALookTitle,
                      style: AppTextStyle.bold16,
                    ),
                    onTap: () {
                      Navigator.pop(dialogCtx);
                      openAddOutfit(
                        context,
                        ref,
                        initialMatchALookImagePath: imagePath,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        primaryLabel: l10n.cancel,
        primaryIsTextButton: true,
        onPrimary: () => Navigator.pop(dialogCtx),
      ),
    );
  }
}
