import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/outfit_details_page.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Outfit _outfit({
  List<String> style = const [],
  String? name,
}) {
  return Outfit(
    id: 1,
    groupId: 3,
    name: name,
    imageUrl: 'https://img.example/1.png',
    style: style,
  );
}

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // _loadGroupOutfits (post-frame) is the only initState fetch while the
  // seed outfit carries no garment ids; it swallows failures, so any
  // benign error response keeps the seed version showing.
  http.Client stubClient() =>
      MockClient((_) async => jsonResponse(envelope({'items': []})));

  testWidgets('untagged outfit shows the "My Collection" fallback', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, OutfitDetailsPage(outfit: _outfit()));
      await tester.pump();
      await tester.pump();

      expect(find.text('My Collection'), findsOneWidget);
      expect(find.byType(CategoryTag), findsNothing);
    }, stubClient);
  });

  testWidgets('style tags render as CategoryTag chips (title-cased)', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(style: ['smart_casual', 'street'])),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Smart Casual'), findsOneWidget);
      expect(find.text('Street'), findsOneWidget);
      expect(find.byType(CategoryTag), findsNWidgets(2));
    }, stubClient);
  });

  testWidgets('the page title falls back to the first tag word', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        OutfitDetailsPage(outfit: _outfit(name: 'Weekend Look')),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Weekend Look'), findsOneWidget);
    }, stubClient);
  });
}
