import 'package:flutter/material.dart';

import '../features/pages/account_page.dart';
import '../features/pages/bag_page.dart';
import '../features/pages/explore_page.dart';
import '../features/pages/saved_page.dart';
import '../features/pages/search_page.dart';
import '../features/widgets/common/explore_nav_bar.dart';

/// Explore's counterpart to `MainShell`, pushed from Home: keeps its tabs
/// alive in an [IndexedStack] (state survives tab switches) and owns
/// [ExploreNavBar].
class ExploreShell extends StatefulWidget {
  const ExploreShell({super.key});

  @override
  State<ExploreShell> createState() => _ExploreShellState();
}

class _ExploreShellState extends State<ExploreShell> {
  ExploreTab _current = ExploreTab.explore;

  void _select(ExploreTab tab) {
    if (tab != _current) setState(() => _current = tab);
  }

  /// Swipe left/right anywhere to cycle tabs (wrapping), as in `MainShell`.
  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 200.0;
    final tabs = ExploreTab.values;
    final i = tabs.indexOf(_current);
    if (velocity < -threshold) {
      _select(tabs[(i + 1) % tabs.length]);
    } else if (velocity > threshold) {
      _select(tabs[(i - 1 + tabs.length) % tabs.length]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: _handleSwipe,
          child: IndexedStack(
            index: ExploreTab.values.indexOf(_current),
            children: const [
              ExplorePage(),
              SearchPage(),
              BagPage(),
              SavedPage(),
              AccountPage(),
            ],
          ),
        ),
        ExploreNavBar(current: _current, onSelect: _select),
      ],
    );
  }
}
