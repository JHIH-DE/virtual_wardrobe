import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uwearis/app/theme/app_text_styles.dart';

// main.dart disables runtime fetching, so every GoogleFonts style the app
// uses must resolve from assets/google_fonts/; a missing file surfaces here
// as an uncaught load error.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => GoogleFonts.config.allowRuntimeFetching = true);

  test('brand wordmark (Sora w700) loads from bundled assets', () async {
    AppTextStyle.brandTitle;
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });

  test('login button labels (Roboto w700) load from bundled assets', () async {
    GoogleFonts.roboto(fontWeight: FontWeight.w700);
    await expectLater(GoogleFonts.pendingFonts(), completes);
  });
}
