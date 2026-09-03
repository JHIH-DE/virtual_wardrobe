import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/features/widgets/common/main_tab_async.dart';
import 'package:uwearis/features/widgets/common/overlays/error_state_widget.dart';

import '../helpers/widget_harness.dart';

void main() {
  Widget bodyFor(AsyncValue<List<int>> state, {VoidCallback? onRetry}) {
    return Scaffold(
      body: state.mainTabBody(
        onRetry: onRetry ?? () {},
        data: (value) => Text('data: ${value.join(",")}'),
      ),
    );
  }

  testWidgets('loading renders an empty box — no spinner (the shell overlay '
      'covers it)', (tester) async {
    await pumpApp(tester, bodyFor(const AsyncLoading()));
    expect(find.text('data: ', skipOffstage: false), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('data calls the builder with the value', (tester) async {
    await pumpApp(tester, bodyFor(const AsyncData([1, 2, 3])));
    expect(find.text('data: 1,2,3'), findsOneWidget);
  });

  testWidgets('error renders ErrorStateWidget; its retry button calls onRetry',
      (tester) async {
    var retries = 0;
    await pumpApp(
      tester,
      bodyFor(
        AsyncError(Exception('boom'), StackTrace.empty),
        onRetry: () => retries++,
      ),
    );
    expect(find.byType(ErrorStateWidget), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(retries, 1);
  });

  testWidgets('an AuthExpiredException error renders nothing (handled by the '
      'page-level listener instead)', (tester) async {
    await pumpApp(
      tester,
      bodyFor(AsyncError(AuthExpiredException(), StackTrace.empty)),
    );
    expect(find.byType(ErrorStateWidget), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });
}
