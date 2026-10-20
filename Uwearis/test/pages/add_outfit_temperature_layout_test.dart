import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';

import '../helpers/add_outfit_harness.dart';
import '../helpers/fake_auth.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

class _EmptyCloset extends GarmentsNotifier {
  @override
  Future<List<Garment>> build() async => const [];
}

/// Today's mean temperature is exactly [mean] (high == low == mean).
class _FixedWeather extends WeatherNotifier {
  _FixedWeather(this.mean);
  final int mean;

  @override
  Future<WeatherData> build() async => WeatherData(
    location: 'Test City',
    temp: mean.toDouble(),
    high: mean,
    low: mean,
    condition: 'Clear',
    weeklyCodes: const [0],
    weeklyHighs: [mean.toDouble()],
    weeklyLows: [mean.toDouble()],
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );
}

/// The app only shows Celsius. Values no wider than the "20°C" sample the
/// side-by-side decision is measured with must never shrink.
const _temperatures = [20, 35, 45, 5, 0, -5, -10, -25, -40];
bool _noWiderThanSample(int t) => t >= -9 && t <= 99;

void main() {
  setUpAll(loadAppFont);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
  });

  final scaledDown = <String>[];
  tearDownAll(() {
    // ignore: avoid_print
    print(
      'scaleDown cases (${scaledDown.length}):\n  ${scaledDown.join('\n  ')}',
    );
  });

  // Plus in-between widths: 385 sits just above the side-by-side threshold
  // (~384pt at 1.0×), the one place a two-digit negative still shrinks;
  // 375 (iPhone SE / mini) and 360 (many Android phones) already stack.
  final cases = [
    ...layoutCases,
    for (final width in [385.0, 375.0, 360.0])
      for (final scale in [1.0, 1.3])
        (width: width, scale: scale, locale: const Locale('en')),
  ];
  for (final c in cases) {
    for (final t in _temperatures) {
      testWidgets('$t°C reads inside its tile at ${describeCase(c)}', (
        tester,
      ) async {
        applyLayoutCase(tester, c, height: 3000);
        await pumpApp(
          tester,
          const AddOutfitPage(),
          overrides: [
            garmentsProvider.overrideWith(_EmptyCloset.new),
            weatherProvider.overrideWith(() => _FixedWeather(t)),
          ],
        );
        await tester.pump();
        await tester.pump();
        await expandFinishOutfit(tester);

        final value = find.text('$t°C');
        final tile = find
            .ancestor(of: value, matching: find.byType(Material))
            .first;
        expectWithin(tester, value, tile);

        final scale =
            tester.getRect(value).width /
            tester.renderObject<RenderBox>(value).size.width;
        if (scale < 0.999) {
          scaledDown.add(
            '${describeCase(c)} · $t°C → ${(scale * 100).toStringAsFixed(0)}%',
          );
        }
        if (_noWiderThanSample(t)) {
          expect(scale, closeTo(1, 0.001), reason: 'must not shrink');
        } else {
          expect(scale, greaterThanOrEqualTo(0.85), reason: 'too small');
        }
      });
    }
  }
}
