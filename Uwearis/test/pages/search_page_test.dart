import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';
import 'package:uwearis/features/pages/search_page.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/fields/app_search_bar.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('the search bar reads "Search" with a camera button beside it', (
    tester,
  ) async {
    await pumpApp(tester, const SearchPage());

    expect(
      find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.text('Search'),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(LucideIcons400.camera), findsOneWidget);
    expect(find.byTooltip('Clear'), findsNothing);

    final bar = tester.getRect(find.byType(AppSearchBar));
    final disc = tester.getRect(find.byType(ActionDisc));
    expect(bar.left, 20);
    expect(disc.left - bar.right, 12);
  });

  testWidgets('the search bar fills the camera disc\'s height, with or '
      'without text', (tester) async {
    await pumpApp(tester, const SearchPage());
    // The fill and border only reach the full height when the field expands.
    expect(tester.widget<TextField>(find.byType(TextField)).expands, isTrue);
    expect(tester.getSize(find.byType(AppSearchBar)).height, ActionDisc.size);

    await tester.enterText(find.byType(TextField), 'shirt');
    await tester.pump();
    expect(tester.getSize(find.byType(AppSearchBar)).height, ActionDisc.size);
  });

  testWidgets('typing swaps the camera for Clear; Clear resets the bar', (
    tester,
  ) async {
    await pumpApp(tester, const SearchPage());

    await tester.enterText(find.byType(TextField), 'tuxedo');
    await tester.pump();

    // The camera disc turns into the clear button; the bar has none of its own.
    expect(find.byIcon(LucideIcons400.camera), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppSearchBar),
        matching: find.byType(IconButton),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(find.text('tuxedo'), findsNothing);
    expect(find.byIcon(LucideIcons400.camera), findsOneWidget);
  });
}
