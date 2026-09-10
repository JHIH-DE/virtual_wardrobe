import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/locale_provider.dart';
import '../core/services/auth_storage.dart';
import '../core/utils/route_observer.dart';
import '../features/pages/login_page.dart';
import '../features/widgets/common/overlays/loading_overlay.dart';
import '../l10n/generated/app_localizations.dart';
import 'main_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  Future<Widget> _bootstrap() async {
    final token = await AuthStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      return const MainShell();
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      theme: AppTheme.light(),
      navigatorObservers: [routeObserver],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      // App-wide "tap off a field to dismiss the keyboard". iOS number /
      // decimal / no-return-key keyboards (Try-On Profile measurements,
      // Finish Outfit temperature, garment brand, …) otherwise trap the
      // keyboard open with no way to close it. translucent + the gesture
      // arena means a tap that lands on a real button or another field
      // still goes there — this only fires on otherwise-inert space.
      builder: (context, child) => GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: child ?? const SizedBox.shrink(),
      ),
      home: FutureBuilder<Widget>(
        future: _bootstrap(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(
              backgroundColor: AppColors.pageBackground,
              body: LoadingOverlay(label: AppLocalizations.of(context).loading),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}
