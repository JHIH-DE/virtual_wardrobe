import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_handler.dart';
import 'floating_nav_bar.dart';
import 'overlays/error_state_widget.dart';

/// Shared main-tab (Home / My Closet / Outfits / Trips) async-list plumbing.
///
/// The list tabs all: mirror their provider's loading flag up to the shell
/// overlay via [MainShellScope.setLoading], route an unrecoverable
/// `AuthExpiredException` to [AuthExpiredHandler], and render nothing while
/// loading / [ErrorStateWidget] on error / their content otherwise.

/// Returns the report callback for a main-tab list provider. Wire it in
/// `initState`'s post-frame callback:
/// ```dart
/// final report = mainTabReporter(context,
///     loadingLabel: l10n.loadingXEllipsis, tab: AppTab.x);
/// report(ref.read(myProvider));
/// ref.listenManual(myProvider, (_, next) => report(next));
/// ```
void Function(AsyncValue<Object?>) mainTabReporter(
  BuildContext context, {
  required String loadingLabel,
  required AppTab tab,
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
  /// The standard main-tab body: an empty box while loading (the shell
  /// overlay covers the screen), [ErrorStateWidget] on error, [data]
  /// otherwise.
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
