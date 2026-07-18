import 'package:flutter/material.dart';

import '../core/services/auth_storage.dart';
import '../features/login_page.dart';
import 'main_shell.dart';
import 'route_observer.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  Future<Widget> _bootstrap() async {
    final token = await AuthStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      return const MainShell();
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      navigatorObservers: [routeObserver],
      home: FutureBuilder<Widget>(
        future: _bootstrap(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data!;
        },
      ),
    );
  }
}
