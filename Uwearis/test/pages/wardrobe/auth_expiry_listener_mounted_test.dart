import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garment_outfits_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/wardrobe/garment_outfits_page.dart';
import 'package:uwearis/features/pages/wardrobe/trip_outfit_selection_page.dart';

import '../../helpers/widget_harness.dart';

class _Outfits extends OutfitsNotifier {
  @override
  Future<List<Outfit>> build() async => const [];

  @override
  Future<void> refreshIfNeeded() async {}
}

/// Mounts [child], then unmounts it in a post-frame callback that runs
/// before the child's own (a parent's `initState` runs first) — the page is
/// gone by the time its post-frame callback registers its listener.
class _UnmountBeforeChildPostFrame extends StatefulWidget {
  const _UnmountBeforeChildPostFrame({required this.child});
  final Widget child;

  @override
  State<_UnmountBeforeChildPostFrame> createState() =>
      _UnmountBeforeChildPostFrameState();
}

class _UnmountBeforeChildPostFrameState
    extends State<_UnmountBeforeChildPostFrame> {
  bool _show = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _show = false);
      final binding = WidgetsBinding.instance;
      binding.buildOwner!.buildScope(binding.rootElement!);
      binding.buildOwner!.finalizeTree();
    });
  }

  @override
  Widget build(BuildContext context) =>
      _show ? widget.child : const SizedBox.shrink();
}

void main() {
  testWidgets('Garment Outfits removed before its first post-frame callback '
      "doesn't use its ref or context", (tester) async {
    await pumpApp(
      tester,
      const _UnmountBeforeChildPostFrame(
        child: GarmentOutfitsPage(garmentId: 7),
      ),
      overrides: [
        garmentOutfitsProvider.overrideWith((ref, id) async => const []),
      ],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GarmentOutfitsPage), findsNothing);
  });

  testWidgets('Trip Outfit Selection removed before its first post-frame '
      "callback doesn't use its ref or context", (tester) async {
    await pumpApp(
      tester,
      const _UnmountBeforeChildPostFrame(child: TripOutfitSelectionPage()),
      overrides: [outfitsProvider.overrideWith(_Outfits.new)],
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TripOutfitSelectionPage), findsNothing);
  });
}
