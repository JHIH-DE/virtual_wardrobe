import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_text_styles.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/garment/garment_image.dart';
import 'package:uwearis/features/widgets/garment/outfit_garment_row.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

Garment _garment(String name) => Garment(
  id: 1,
  name: name,
  category: GarmentCategory.top,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

Future<void> _pump(WidgetTester tester, LayoutCase c, String name) async {
  applyLayoutCase(tester, c);
  await pumpApp(
    tester,
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            OutfitGarmentRow(garment: _garment(name), subtitle: 'Top'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFont);

  testWidgets('name is bold14, category line regular14', (tester) async {
    await _pump(tester, layoutCases.first, 'Tee');
    expect(
      tester.widget<Text>(find.text('Tee')).style?.fontSize,
      AppTextStyle.bold14.fontSize,
    );
    expect(
      tester.widget<Text>(find.text('Top')).style?.fontSize,
      AppTextStyle.regular14.fontSize,
    );
  });

  testWidgets('the photo sits beside the text at default size', (tester) async {
    await _pump(tester, layoutCases.first, 'Weatherproofed');
    final photo = tester.getRect(find.byType(GarmentImage));
    expect(
      photo.right,
      lessThanOrEqualTo(tester.getRect(find.text('Weatherproofed')).left),
    );
  });

  testWidgets('the photo moves above a word too wide to fit beside it', (
    tester,
  ) async {
    const c = (width: 320.0, scale: 2.0, locale: Locale('en'));
    await _pump(tester, c, 'Weatherproofed');
    final name = find.text('Weatherproofed');
    final photo = tester.getRect(find.byType(GarmentImage));
    expect(photo.bottom, lessThanOrEqualTo(tester.getRect(name).top));
    expectNoBrokenWords(tester, name);
  });
}
