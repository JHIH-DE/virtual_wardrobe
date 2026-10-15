import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_handler.dart';
import 'main_nav_bar.dart';
import 'overlays/error_state_widget.dart';

/// Returns the report callback for a main-tab list provider (My Closet /
/// Outfits / Trips): mirrors loading to the shell overlay and routes auth
/// expiry to [AuthExpiredHandler]. Wire it in `initState`'s post-frame
/// callback:
/// ```dart
/// final report = mainTabReporter(context,
///     loadingLabel: l10n.loadingXEllipsis, tab: MainTab.x);
/// report(ref.read(myProvider));
/// ref.listenManual(myProvider, (_, next) => report(next));
/// ```
void Function(AsyncValue<Object?>) mainTabReporter(
  BuildContext context, {
  required String loadingLabel,
  required MainTab tab,
}) {
  return (state) {
    if (state.hasError && state.error is AuthExpiredException) {
      AuthExpiredHandler.handle(context);
    }
    MainShellScope.of(
      context,
    )?.setLoading(state.isLoading, label: loadingLabel, tab: tab);
  };
}

extension MainTabAsyncBody<T> on AsyncValue<T> {
  /// Empty while loading — the shell overlay covers the screen.
  Widget mainTabBody({
    required Widget Function(T value) data,
    required VoidCallback onRetry,
  }) {
    return when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => ErrorStateWidget(error: e, onRetry: onRetry),
      data: data,
    );
  }
}
