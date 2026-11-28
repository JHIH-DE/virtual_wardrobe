import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

import '../config.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';

/// Google sign-in → backend JWT → must be an admin (`users.is_admin`).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  StreamSubscription<GoogleSignInAuthenticationEvent>? _events;
  bool _ready = false;
  bool _signingIn = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = CmsScope.read(context).client.takeSignOutReason();
    _init();
  }

  Future<void> _init() async {
    if (Config.googleClientId.isEmpty) {
      setState(
        () => _message =
            '缺少 GOOGLE_CLIENT_ID：請用 --dart-define-from-file=dart_defines/dev.json 啟動。',
      );
      return;
    }
    try {
      final signIn = GoogleSignIn.instance;
      await signIn.initialize(clientId: Config.googleClientId);
      _events = signIn.authenticationEvents.listen(
        _onEvent,
        onError: (Object e) {
          if (mounted) setState(() => _message = 'Google 登入失敗：$e');
        },
      );
      if (mounted) setState(() => _ready = true);
      unawaited(signIn.attemptLightweightAuthentication());
    } catch (e) {
      if (mounted) setState(() => _message = 'Google 登入初始化失敗：$e');
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  Future<void> _onEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn || _signingIn) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null) return;
    final api = CmsScope.read(context);
    setState(() {
      _signingIn = true;
      _message = null;
    });
    try {
      await api.client.signInWithGoogle(idToken);
      final adminId = await api.adminUserId();
      if (adminId != null) {
        api.client.confirmSession(adminId);
      } else {
        api.client.signOut();
        await GoogleSignIn.instance.signOut();
        if (mounted) setState(() => _message = '${event.user.email} 不是管理員帳號。');
      }
    } catch (e) {
      api.client.signOut();
      if (mounted) setState(() => _message = errorText(e));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Uwearis 雜誌後台',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '使用管理員的 Google 帳號登入',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_signingIn)
                    const CircularProgressIndicator()
                  else if (_ready)
                    SizedBox(height: 44, child: gsi_web.renderButton()),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    '後端：${Config.apiBaseUrl}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
