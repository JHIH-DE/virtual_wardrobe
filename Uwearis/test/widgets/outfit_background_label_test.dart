import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/background_option.dart';
import 'package:uwearis/features/widgets/outfit/outfit_background_field.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

void main() {
  test("the backend's label is the name", () {
    expect(
      backgroundLabel(
        const BackgroundOption(id: 16, name: 'tokyo_street_2', label: '東京街頭 2'),
      ),
      '東京街頭 2',
    );
  });

  test('without a label (an older backend) the code reads as words', () {
    expect(
      backgroundLabel(const BackgroundOption(id: 9, name: 'rooftop_garden')),
      'Rooftop Garden',
    );
    expect(
      backgroundLabel(
        const BackgroundOption(id: 9, name: 'rooftop_garden', label: '  '),
      ),
      'Rooftop Garden',
    );
  });

  test('category tabs are translated', () {
    final zh = lookupAppLocalizations(const Locale('zh', 'TW'));
    expect(backgroundCategoryLabel(zh, BackgroundCategory.indoor), '室內');
    expect(backgroundCategoryLabel(zh, BackgroundCategory.urban), '室外');
    expect(backgroundCategoryLabel(zh, BackgroundCategory.nature), '自然');
    expect(backgroundCategoryLabel(zh, BackgroundCategory.other), '其他');
  });
}
