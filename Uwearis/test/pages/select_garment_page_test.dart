import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/select_garment_page.dart';

import '../helpers/widget_harness.dart';

Garment _garment({
  required int id,
  required GarmentCategory category,
  String name = 'Item',
}) {
  return Garment(
    id: id,
    garmentId: id,
    name: name,
    category: category,
    subCategory: '',
    uploadUrl: '',
    objectName: '',
  );
}

void main() {
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final garments = [
    _garment(id: 1, category: GarmentCategory.top, name: 'Tee'),
    _garment(id: 2, category: GarmentCategory.bottom, name: 'Jeans'),
  ];

  testWidgets('tab mode filters the grid by the selected category tab', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      SelectGarmentPage(
        title: 'Add Garment',
        garments: garments,
        categoryTabs: const [GarmentCategory.top, GarmentCategory.bottom],
      ),
    );
    await tester.pump();

    // Opens on the first tab.
    expect(find.text('Tee'), findsOneWidget);
    expect(find.text('Jeans'), findsNothing);

    await tester.tap(find.text('Bottom'));
    await tester.pumpAndSettle();

    expect(find.text('Jeans'), findsOneWidget);
    expect(find.text('Tee'), findsNothing);
  });

  testWidgets('tab mode opens on the category passed as the initial tab', (
    tester,
  ) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      SelectGarmentPage(
        title: 'Add Garment',
        category: GarmentCategory.bottom,
        garments: garments,
        categoryTabs: const [GarmentCategory.top, GarmentCategory.bottom],
      ),
    );
    await tester.pump();

    expect(find.text('Jeans'), findsOneWidget);
    expect(find.text('Tee'), findsNothing);
  });

  testWidgets('tapping a garment pops with the SelectGarmentResult', (
    tester,
  ) async {
    useTallSurface(tester);
    SelectGarmentResult? result;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<SelectGarmentResult>(
                  MaterialPageRoute(
                    builder: (_) => SelectGarmentPage(
                      title: 'Add Garment',
                      garments: garments,
                      categoryTabs: const [
                        GarmentCategory.top,
                        GarmentCategory.bottom,
                      ],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tee'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.garment?.id, 1);
  });
}
