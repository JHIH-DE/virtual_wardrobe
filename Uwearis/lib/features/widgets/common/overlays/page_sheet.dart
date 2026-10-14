import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../buttons/action_disc_button.dart';

/// Opens a page sheet — a bottom sheet used as a page of its own, for a
/// self-contained view (e.g. Garment Details' Closet Match analysis) that
/// slides up over the current page instead of being pushed as a route.
///
/// Its top edge sits level with the top of the page's `AppToolBar` action
/// discs, so it just covers them (the toolbar's title row shows above it,
/// under the modal barrier). Its chrome is just a top row with [title] centred,
/// a close (X) button on a translucent disc at the right, and an optional
/// [leading] action at the left (pass a [PageSheetAction] so it matches the
/// X) — no drag handle or divider; [builder]'s content fills the rest of the height
/// below it, so make it scrollable if it can overflow.
///
/// The sheet's background is [AppColors.pageBackground], like the page it
/// stands in for.
///
/// A separate design from [showPickerSheet]'s "pick one from a list"
/// chrome, so it deliberately doesn't share that header.
Future<T?> pageSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? leading,
}) {
  // From the View, not MediaQuery.of(context): a Scaffold with an app bar
  // strips the status-bar inset from its body's MediaQuery, which is where
  // callers usually open this from.
  final media = MediaQueryData.fromView(View.of(context));
  // The top of AppToolBar's action discs, centred in its toolbar-height row.
  final sheetTop =
      media.padding.top + (AppDimens.toolbarHeight - ActionDisc.size) / 2;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.pageBackground,
    clipBehavior: Clip.antiAlias,
    // Full screen width (Material 3 otherwise caps a sheet at 640): it
    // stands in for the page body it covers.
    constraints: const BoxConstraints(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SizedBox(
      height: media.size.height - sheetTop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ActionDisc.edgeInset puts each disc 20 below the sheet's top and
          // 20 in from its side, matching AppToolBar. The title keeps the
          // same inset on both sides so it stays centred on the whole sheet
          // without running under either.
          Padding(
            padding: const EdgeInsets.only(top: ActionDisc.edgeInset),
            child: SizedBox(
              height: AppDimens.toolbarHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal:
                          AppDimens.toolbarHeight + ActionDisc.edgeInset,
                    ),
                    child: Text(
                      title,
                      style: AppTextStyle.bold22,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (leading != null)
                    Positioned(left: ActionDisc.edgeInset, child: leading),
                  Positioned(
                    right: ActionDisc.edgeInset,
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

/// A [pageSheet] header action — an icon on a translucent disc in a
/// 48px tap target, the sheet's own close (X) button's look. Pass one as
/// [pageSheet]'s `leading` for a matching action at the top left. While
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: SizedBox.square(
          dimension: AppDimens.toolbarHeight,
          child: Center(
            child: ActionDisc(
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  : Icon(
                      icon,
                      size: ActionDisc.iconSize,
                      color: AppColors.icon,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
