import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme/app_text_styles.dart';

/// For a details page whose body opens with the item's name instead of a
/// toolbar title: the toolbar fades that name in once it has scrolled away,
/// and out again back near the top.
///
/// Wire it with [toolbarTitleScrollController] on the page's scroll view,
/// [toolbarTitleAnchorKey] on the in-page name, and
/// `AppToolBar(titleWidget: buildFadingToolbarTitle(name))`.
mixin FadingToolbarTitle<T extends StatefulWidget> on State<T> {
  final ScrollController toolbarTitleScrollController = ScrollController();
  final GlobalKey toolbarTitleAnchorKey = GlobalKey();
  final ValueNotifier<bool> _showsToolbarTitle = ValueNotifier(false);

  // Scroll offset at which the in-page name's bottom reaches the toolbar.
  double? _anchorBottomOffset;

  // Hidden again only this far back above the threshold, so resting near it
  // doesn't flicker.
  static const double _hysteresis = 8;

  @override
  void initState() {
    super.initState();
    toolbarTitleScrollController.addListener(_updateToolbarTitle);
  }

  @override
  void dispose() {
    toolbarTitleScrollController.dispose();
    _showsToolbarTitle.dispose();
    super.dispose();
  }

  void _updateToolbarTitle() {
    if (!toolbarTitleScrollController.hasClients) return;
    final anchor =
        toolbarTitleAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    // The list may drop the name once it's far off screen; keep the last
    // measured position then.
    if (anchor != null && anchor.attached) {
      _anchorBottomOffset =
          RenderAbstractViewport.of(
            anchor,
          ).getOffsetToReveal(anchor, 0).offset +
          anchor.size.height;
    }
    final threshold = _anchorBottomOffset;
    if (threshold == null) return;
    final offset = toolbarTitleScrollController.offset;
    if (_showsToolbarTitle.value) {
      if (offset < threshold - _hysteresis) _showsToolbarTitle.value = false;
    } else if (offset >= threshold) {
      _showsToolbarTitle.value = true;
    }
  }

  /// One line, ellipsized; `AppBar` keeps it between the back button and the
  /// actions. Invisible (and silent to screen readers) until shown.
  Widget buildFadingToolbarTitle(String text) {
    return ValueListenableBuilder<bool>(
      valueListenable: _showsToolbarTitle,
      builder: (context, shows, _) => AnimatedOpacity(
        opacity: shows ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: AppTextStyle.bold22,
        ),
      ),
    );
  }
}
