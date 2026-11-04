import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/features/pages/explore/explore_page.dart';
import 'package:uwearis/features/pages/settings/settings_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Explore\'s toolbar opens Settings and has no notifications '
      'bell', (tester) async {
    await http.runWithClient(
      () async {
        await pumpApp(tester, const ExplorePage());
        expect(find.byIcon(Icons.notifications_none), findsNothing);

        await tester.tap(find.byTooltip('Settings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(SettingsPage), findsOneWidget);
      },
      () => MockClient(
        (_) async => jsonResponse(
          envelope({'name': 'Test User', 'email': 'test@example.com'}),
        ),
      ),
    );
  });
}
