import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/utils/external_links.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

class _FakeLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final launched = <(String, PreferredLaunchMode)>[];
  bool result = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url, options.mode));
    return result;
  }
}

String _jwt(Object payload) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  late _FakeLauncher launcher;
  String? clipboard;

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
    setUpFakeAuth(accessToken: _jwt({'sub': '42'}));
    PackageInfo.setMockInitialValues(
      appName: 'Uwearis',
      packageName: 'com.uwearis.app',
      version: '1.0.0',
      buildNumber: '16',
      buildSignature: '',
    );
    clipboard = null;
  });

  Future<void> pumpTrigger(
    WidgetTester tester,
    Future<void> Function(BuildContext) action,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => action(context),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
  }

  testWidgets('policy pages open in the in-app browser', (tester) async {
    await pumpTrigger(tester, openPrivacyPolicy);
    await pumpTrigger(tester, openTermsOfService);

    expect(launcher.launched, [
      (AppConfig.privacyPolicyUrl, PreferredLaunchMode.inAppBrowserView),
      (AppConfig.termsOfServiceUrl, PreferredLaunchMode.inAppBrowserView),
    ]);
  });

  testWidgets('a page that fails to open shows an error', (tester) async {
    launcher.result = false;
    await pumpTrigger(tester, openPrivacyPolicy);

    expect(
      find.text("Couldn't open the page. Please try again later."),
      findsOneWidget,
    );
  });

  testWidgets('support email carries version and user id, spaces as %20', (
    tester,
  ) async {
    await pumpTrigger(tester, contactSupport);

    final (url, mode) = launcher.launched.single;
    expect(mode, PreferredLaunchMode.externalApplication);
    expect(url, startsWith('mailto:${AppConfig.supportEmail}?subject='));
    expect(url, isNot(contains('+')));
    final body = Uri.decodeComponent(url.split('&body=').last);
    expect(body, contains('App version: 1.0.0 (16)'));
    expect(body, contains('User ID: 42'));
  });

  testWidgets('with no mail app, copies the address and says so', (
    tester,
  ) async {
    launcher.result = false;
    await pumpTrigger(tester, contactSupport);

    expect(clipboard, AppConfig.supportEmail);
    expect(find.textContaining(AppConfig.supportEmail), findsOneWidget);
  });
}
