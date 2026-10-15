import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../buttons/action_disc_button.dart';

/// A bottom sheet used as a page of its own (e.g. Closet Match). Its top
/// edge is level with the page toolbar's action discs. [builder]'s content
/// fills the remaining height, so make it scrollable if it can overflow.
/// Pass a [PageSheetAction] as [leading] to match the close button.
Future<T?> pageSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  Widget? leading,
}) {
  // Not MediaQuery.of(context): a Scaffold with an app bar strips the
  // status-bar inset from its body's MediaQuery.
  final media = MediaQueryData.fromView(View.of(context));
  final sheetTop =
      media.padding.top + (AppDimens.toolbarHeight - ActionDisc.size) / 2;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.pageBackground,
    clipBehavior: Clip.antiAlias,
    // Material 3 otherwise caps sheet width at 640.
    constraints: const BoxConstraints(),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SizedBox(
      height: media.size.height - sheetTop,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

/// A [pageSheet] header action styled like its close button. While [busy],
/// a spinner replaces the icon and taps are ignored.
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
