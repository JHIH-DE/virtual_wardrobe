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

/// Lets a photo shared into Uwearis from another app's system "Share" sheet
/// land on the same Add Clothing / Match a Look flows [MainShell]'s own
/// quick-action button opens — the user picks which one via a small
/// dialog. Android only for now: `AndroidManifest.xml`'s `SEND`/
/// `SEND_MULTIPLE` `image/*` intent-filters are what actually register
/// Uwearis in the OS share sheet. iOS needs a separate Share Extension
/// Xcode target (App Group entitlement, its own provisioning profile) this
/// repo doesn't have yet — [listen] is harmless to call on iOS too, it
/// just never receives anything until that native work exists.
///
/// [listen] is called once from [MainShell]'s `initState` and covers both
/// ways a share can reach the app: already cold-started by it
/// ([ReceiveSharingIntent.getInitialMedia]) and received while already
/// running ([ReceiveSharingIntent.getMediaStream]).
class SharedMediaHandler {
  static StreamSubscription<List<SharedMediaFile>>? _subscription;

  static void listen(BuildContext context, WidgetRef ref) {
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (media.isEmpty || !context.mounted) return;
      // Read the path before reset() — some implementations (including the
      // package's own test mock) clear the very list this callback holds a
      // reference to, not a separate copy.
      final path = media.first.path;
      ReceiveSharingIntent.instance.reset();
      _handle(context, ref, path);
    });

    // Re-listening (MainShell only ever builds once, but cheap insurance
    // against ever double-registering) replaces rather than stacks.
    unawaited(_subscription?.cancel());
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen((
      media,
    ) {
      if (media.isNotEmpty && context.mounted) {
        _handle(context, ref, media.first.path);
      }
    });
  }

  /// Only the first photo of a multi-share is used — both destination
  /// flows (Add Clothing, Match a Look) take one photo at a time; batching
  /// a `SEND_MULTIPLE` share is future scope, not v1.
  static Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    String imagePath,
  ) async {
    // Nothing useful to do with a shared photo while logged out — both
    // destination flows need an authenticated user, and there's no
    // "resume after login" state kept here; the user can just re-share
    // once they're in.
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
                          // Land on My Closet regardless of which tab was
                          // active when the share arrived — matches the
                          // quick-action's own "+ Add Clothing" behavior.
                          MainShellScope.of(
                            context,
                          )?.selectTab(MainTab.closet);
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
