import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/features/pages/lifestyle_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

/// Answers every PATCH /users/me, recording each body. [fail] makes the
/// next responses 500s; [hold] parks responses until released.
class _ProfileBackend {
  final List<Map<String, dynamic>> patches = [];
  bool fail = false;
  Completer<void>? hold;

  MockClient get client => MockClient((req) async {
    if (req.method != 'PATCH') return jsonResponse(envelope({}));
    patches.add(jsonDecode(req.body) as Map<String, dynamic>);
    if (hold != null) await hold!.future;
    if (fail) return jsonResponse({'success': false}, status: 500);
    return jsonResponse(envelope({'name': 'Test User'}));
  });
}

/// AppToolBar's back arrow — an IconButton around the arrow asset.
final _backButton = find.ancestor(
  of: find.image(const AssetImage('assets/images/page_arrow_left.png')),
  matching: find.byType(IconButton),
);

void main() {
  setUp(() {
    setUpFakeAuth();
    SharedPreferences.setMockInitialValues({});
  });

  /// Pushes LifestylePage on top of a placeholder home so popping is
  /// observable.
  Future<void> openLifestyle(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LifestylePage()),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(_backButton);
    await tester.pumpAndSettle();
  }

  testWidgets('has no Save button and saves a comfort change immediately, '
      'silently', (tester) async {
    final backend = _ProfileBackend();
    await http.runWithClient(() async {
      await openLifestyle(tester);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(backend.patches.single['temperature_offset_c'], 1);
      expect(find.text('Changes Saved'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), 1);
    }, () => backend.client);
  });

  testWidgets('picking a different occasion saves the whole weekly '
      'schedule', (tester) async {
    final backend = _ProfileBackend();
    await http.runWithClient(() async {
      await openLifestyle(tester);

      await tester.tap(find.text('Work').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Party'));
      await tester.pumpAndSettle();

      final schedule =
          backend.patches.single['weekly_schedule'] as Map<String, dynamic>;
      expect(schedule.length, 7);
      expect(schedule['mon'], isNot('work'));
      expect(schedule['tue'], 'work');
    }, () => backend.client);
  });

  testWidgets('back with nothing pending pops without saving', (tester) async {
    final backend = _ProfileBackend();
    await http.runWithClient(() async {
      await openLifestyle(tester);
      await tapBack(tester);

      expect(find.byType(LifestylePage), findsNothing);
      expect(backend.patches, isEmpty);
    }, () => backend.client);
  });

  testWidgets('back while a save is in flight waits for it behind the '
      'saving overlay, then pops', (tester) async {
    final backend = _ProfileBackend()..hold = Completer<void>();
    await http.runWithClient(() async {
      await openLifestyle(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();

      await tester.tap(_backButton);
      await tester.pump();
      expect(find.byType(LifestylePage), findsOneWidget);
      expect(find.textContaining('Saving'), findsOneWidget);

      backend.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LifestylePage), findsNothing);
      expect(backend.patches, hasLength(1));
    }, () => backend.client);
  });

  testWidgets('a failed save shows the error dialog, and Retry saves '
      'again', (tester) async {
    final backend = _ProfileBackend()..fail = true;
    await http.runWithClient(() async {
      await openLifestyle(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save your profile. Please try again."),
        findsOneWidget,
      );
      backend.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(backend.patches, hasLength(2));
      expect(backend.patches.last['temperature_offset_c'], 1);
      expect(find.text('Retry'), findsNothing);
    }, () => backend.client);
  });

  testWidgets('leaving with a change that keeps failing asks first; Cancel '
      'stays, Don\'t Save leaves', (tester) async {
    final backend = _ProfileBackend()..fail = true;
    await http.runWithClient(() async {
      await openLifestyle(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel')); // dismiss the error dialog
      await tester.pumpAndSettle();

      await tapBack(tester);
      expect(find.text('You have unsaved changes'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(LifestylePage), findsOneWidget);

      await tapBack(tester);
      await tester.tap(find.text("Don't Save"));
      await tester.pumpAndSettle();
      expect(find.byType(LifestylePage), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('temperature_offset'), isNull);
    }, () => backend.client);
  });

  testWidgets('system back is intercepted the same way while a change is '
      'unsaved', (tester) async {
    final backend = _ProfileBackend()..fail = true;
    await http.runWithClient(() async {
      await openLifestyle(tester);
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('You have unsaved changes'), findsOneWidget);
      expect(find.byType(LifestylePage), findsOneWidget);

      backend.fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(LifestylePage), findsNothing);
      expect(backend.patches, hasLength(3));
    }, () => backend.client);
  });
}
