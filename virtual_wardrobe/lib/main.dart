import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'login_page.dart';

void main() {
  runApp(const VirtualWardrobeApp());
}

class VirtualWardrobeApp extends StatelessWidget {
  const VirtualWardrobeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Wardrobe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const LoginPage(),
    );
  }
}