import 'package:flutter/material.dart';
import '../data/token_storage.dart';
import '../features/login_page.dart';
import '../features/home_page.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  Future<Widget> _bootstrap() async {
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      return const HomePage();
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<Widget>(
        future: _bootstrap(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data!;
        },
      ),
    );
  }
}