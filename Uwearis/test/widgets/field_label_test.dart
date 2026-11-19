import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/field_label.dart';

void main() {
  Future<double?> fontSizeIn(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      Localizations(
        locale: locale,
        delegates: const [
          DefaultWidgetsLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
        ],
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: FieldLabel('LABEL'),
        ),
      ),
    );
    return tester.widget<Text>(find.text('LABEL')).style?.fontSize;
  }

  testWidgets('Chinese gets a larger label; English keeps 12px', (
    tester,
  ) async {
    expect(
      await fontSizeIn(tester, const Locale('zh', 'TW')),
      FieldLabel.cjkFontSize,
    );
    expect(await fontSizeIn(tester, const Locale('en')), 12);
  });
}
