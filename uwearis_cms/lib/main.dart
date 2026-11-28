import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_theme.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import 'api/api_client.dart';
import 'api/cms_api.dart';
import 'pages/home_shell.dart';
import 'pages/login_page.dart';
import 'widgets/cms_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // As in the App: fonts come from the bundled files, never the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  // AppTextStyle names the family without a package prefix; the file comes
  // bundled with the App package.
  await (FontLoader('NotoSansTC')..addFont(
        rootBundle.load('packages/uwearis/assets/fonts/NotoSansTC.ttf'),
      ))
      .load();
  runApp(CmsApp(api: CmsApi(ApiClient())));
}

class CmsApp extends StatefulWidget {
  final CmsApi api;
  const CmsApp({super.key, required this.api});

  @override
  State<CmsApp> createState() => _CmsAppState();
}

class _CmsAppState extends State<CmsApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.api.client.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.api.client.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Signed out (or the session expired) while an editor was open: close
  /// every page so the login screen shows.
  void _onSessionChanged() {
    if (!widget.api.client.isSignedIn) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  /// The App's theme with a light toolbar: the App draws its own toolbars,
  /// so its dark AppBar theme left the editors' action buttons (Publish,
  /// Save) dark on dark.
  static final ThemeData _theme = AppTheme.light().copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shape: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return CmsScope(
      api: widget.api,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Uwearis 雜誌後台',
        debugShowCheckedModeBanner: false,
        theme: _theme,
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CmsScope.of(context).client.isSignedIn
              ? const HomeShell()
              : const LoginPage(),
        ),
      ),
    );
  }
}
