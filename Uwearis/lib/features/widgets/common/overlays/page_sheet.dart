import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../cards/card_corner_badge.dart';

/// Opens a page sheet — a bottom sheet used as a page of its own, for a
/// self-contained view (e.g. Garment Details' Closet Match analysis) that
/// slides up over the current page instead of being pushed as a route.
///
/// Its top edge lines up with the bottom of the page's `AppToolBar` — the
/// toolbar stays visible (under the modal barrier) and the sheet fills
/// everything below it. Its chrome is just a top row with [title] centred,
/// a close (X) button on a translucent disc at the right, and an optional
/// [leading] action at the left (pass a [PageSheetAction] so it matches the
/// X) — no drag handle or divider; [builder]'s content fills the rest of the height
/// below it, so make it scrollable if it can overflow.
///
/// The sheet paints [AppColors.uwearisGradient] behind everything.
///
/// A separate design from [showPickerSheet]'s "pick one from a list"
/// chrome, so it deliberately doesn't share that header.
Future<T?> showPageSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? leading,
}) {
  // From the View, not MediaQuery.of(context): a Scaffold with an app bar
  // strips the status-bar inset from its body's MediaQuery, which is where
  // callers usually open this from.
  final media = MediaQueryData.fromView(View.of(context));
  final toolBarBottom = media.padding.top + AppDimens.toolbarHeight;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    clipBehavior: Clip.antiAlias,
    // Full screen width (Material 3 otherwise caps a sheet at 640): it
    // stands in for the page body it covers.
    constraints: const BoxConstraints(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Container(
      height: media.size.height - toolBarBottom,
      decoration: const BoxDecoration(gradient: AppColors.uwearisGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A [PageSheetAction]'s 36px disc is centred in its 48px tap target,
          // so this puts each disc 16 below the sheet's top and 16 in from
          // its side. The title keeps the same inset on both sides so it
          // stays centred on the whole sheet without running under either.
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: SizedBox(
              height: AppDimens.toolbarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.toolbarHeight + 10,
                    ),
                    child: Text(
                      title,
                      style: AppTextStyle.bold20,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (leading != null) Positioned(left: 10, child: leading),
                  Positioned(
                    right: 10,
                    child: PageSheetAction(
                      icon: Icons.close,
                      label: AppLocalizations.of(sheetContext).close,
                      onTap: () => Navigator.pop(sheetContext),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: builder(sheetContext),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A [showPageSheet] header action — an icon on a translucent disc in a
/// 48px tap target, the sheet's own close (X) button's look. Pass one as
/// [showPageSheet]'s `leading` for a matching action at the top left. While
/// [busy], a small spinner replaces the icon and taps are ignored.
class PageSheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const PageSheetAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !busy,
      label: label,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CardCornerBadge(
            icon: icon,
            iconColor: busy ? Colors.transparent : AppColors.icon,
            backgroundColor: AppColors.surfaceTranslucent,
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [],
            size: 36,
            iconSize: 20,
            hitTargetSize: const Size.square(AppDimens.toolbarHeight),
            onTap: busy ? null : onTap,
          ),
          if (busy)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
        ],
      ),
    );
  }
}
