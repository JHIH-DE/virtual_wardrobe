import 'package:flutter/material.dart';

import '../../features/login_page.dart';
import '../../data/token_storage.dart';

class AuthExpiredException implements Exception {
  final String _message;
  AuthExpiredException([this._message = 'Authentication expired']);
  @override
  String toString() => _message;
}

class AuthExpiredHandler {

  static Future<void> handle(BuildContext context) async {
    await TokenStorage.clear();

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please log in again to continue.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 關閉對話框
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
