import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/fading_toolbar_title.dart';

import '../helpers/widget_harness.dart';

class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> with FadingToolbarTitle {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppToolBar(
        title: 'Details',
        titleWidget: buildFadingToolbarTitle('Blue Oxford'),
      ),
      body: ListView(
        controller: toolbarTitleScrollController,
        children: [
          const SizedBox(height: 20),
          SizedBox(
            key: toolbarTitleAnchorKey,
            height: 30,
            child: const Text('Blue Oxford'),
          ),
          const SizedBox(height: 3000),
        ],
      ),
    );
  }
}

void main() {
  // The anchor's bottom sits 50px into the list.
  const threshold = 50.0;

  testWidgets('fades in past the in-page name and only fades out again a few '
      'pixels above it, so resting at the edge never flickers', (tester) async {
    await pumpApp(tester, const _Page());
    final state = tester.state<_PageState>(find.byType(_Page));
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.descendant(
              of: find.byType(AppBar),
              matching: find.text('Blue Oxford'),
            ),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    Future<void> jumpTo(double offset) async {
      state.toolbarTitleScrollController.jumpTo(offset);
      await tester.pumpAndSettle();
    }

    expect(opacity(), 0);
    await jumpTo(threshold - 1);
    expect(opacity(), 0);
    await jumpTo(threshold);
    expect(opacity(), 1);
    // Back a little: within the hysteresis band, stays shown.
    await jumpTo(threshold - 4);
    expect(opacity(), 1);
    await jumpTo(threshold - 9);
    expect(opacity(), 0);
    // And not shown again until past the threshold once more.
    await jumpTo(threshold - 4);
    expect(opacity(), 0);
  });
}
