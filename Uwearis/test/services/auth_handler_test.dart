import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/auth_handler.dart';

void main() {
  testWidgets(
    'invalidateSignedInProviders runs without throwing when none of the '
    "per-user providers it invalidates have been read yet — the actual "
    "effect of container.invalidate on an already-mounted, still-watched "
    "provider is covered by home_page_test.dart's own regression test",
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        () => invalidateSignedInProviders(capturedContext),
        returnsNormally,
      );
    },
  );
}
