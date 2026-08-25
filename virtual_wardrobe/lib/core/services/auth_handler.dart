import 'package:flutter/material.dart';

import '../../features/pages/login_page.dart';
import '../../features/widgets/common/overlays/app_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_storage.dart';

class AuthExpiredException implements Exception {
  final String _message;
  AuthExpiredException([this._message = 'Authentication expired']);
  @override
  String toString() => _message;
}

class AuthExpiredHandler {
  // Several tabs can be mounted at once (e.g. under a persistent shell),
  // each independently watching for a 401. Without this guard, a single
  // expired token would trigger this dialog+redirect once per tab.
  static bool _isHandling = false;

  static Future<void> handle(BuildContext context) async {
    if (_isHandling) return;
    _isHandling = true;
    try {
      await AuthStorage.clear();

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          title: l10n.sessionExpiredTitle,
          body: l10n.sessionExpiredMessage,
          primaryLabel: l10n.ok,
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

      if (!context.mounted) return;

      // Navigate after the dialog closes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } finally {
      _isHandling = false;
    }
  }
}
