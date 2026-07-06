import 'package:flutter/material.dart';

import '../../features/login_page.dart';
import '../../features/widgets/app_dialog.dart';
import 'auth_storage.dart';

class AuthExpiredException implements Exception {
  final String _message;
  AuthExpiredException([this._message = 'Authentication expired']);
  @override
  String toString() => _message;
}

class AuthExpiredHandler {
  static Future<void> handle(BuildContext context) async {
    await AuthStorage.clear();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppDialog(
        title: 'Session Expired',
        body: 'Your session has expired. Please log in again to continue.',
        primaryLabel: 'OK',
        onPrimary: () => Navigator.of(ctx).pop(),
      ),
    );

    if (!context.mounted) return;

    // 彈窗關閉後，執行跳轉
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
