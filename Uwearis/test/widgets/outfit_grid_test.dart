import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/widgets/common/overlays/empty_state_placeholder.dart';
import 'package:uwearis/features/widgets/outfit/outfit_card.dart';
import 'package:uwearis/features/widgets/outfit/outfit_grid.dart';

import '../helpers/widget_harness.dart';

Outfit _outfit(int id) => Outfit.fromJson({
  'outfit_id': id,
  'group_id': id * 10,
  'result_image_url': '',
});

void main() {
  Widget grid(
    List<Outfit> outfits, {
    Future<void> Function()? onRefresh,
    void Function(Outfit)? onTap,
  }) {
    return Scaffold(
      body: OutfitGrid(
        outfits: outfits,
        onRefresh: onRefresh ?? () async {},
        onOutfitTap: onTap ?? (_) {},
        emptyMessage: 'Nothing here yet',
      ),
    );
  }

  testWidgets('renders one OutfitCard per outfit', (tester) async {
    await pumpApp(tester, grid([_outfit(1), _outfit(2), _outfit(3)]));
    expect(find.byType(OutfitCard), findsNWidgets(3));
    expect(find.byType(EmptyStatePlaceholder), findsNothing);
  });

  testWidgets('an empty list shows the empty message, no grid', (tester) async {
    await pumpApp(tester, grid(const []));
    expect(find.byType(OutfitCard), findsNothing);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('tapping a card calls onOutfitTap with that outfit', (
    tester,
  ) async {
    Outfit? tapped;
    await pumpApp(
      tester,
      grid([_outfit(1), _outfit(2)], onTap: (o) => tapped = o),
    );
    await tester.tap(find.byType(OutfitCard).first);
    expect(tapped?.id, 1);
  });

  testWidgets('is wrapped in a RefreshIndicator in both states', (tester) async {
    await pumpApp(tester, grid([_outfit(1)]));
    expect(find.byType(RefreshIndicator), findsOneWidget);

    await pumpApp(tester, grid(const []));
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
