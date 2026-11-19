import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/photo_source_dialog.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/widget_harness.dart';

/// The album: answers with [next] (null = cancelled), fails with [error],
/// or holds the pick until the test completes [held].
class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  String? next;
  Object? error;
  bool hold = false;
  Completer<XFile?>? held;
  int picks = 0;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    picks++;
    if (hold) return (held = Completer<XFile?>()).future;
    if (error != null) return Future.error(error!);
    return Future.value(next == null ? null : XFile(next!));
  }
}

void main() {
  late _FakeImagePicker picker;
  late ImagePickerPlatform original;

  setUp(() {
    original = ImagePickerPlatform.instance;
    picker = _FakeImagePicker();
    ImagePickerPlatform.instance = picker;
  });

  tearDown(() => ImagePickerPlatform.instance = original);

  /// A screen with a button that opens the dialog; [result] completes with
  /// what it returned.
  Future<Completer<String?>> openDialog(WidgetTester tester) async {
    final result = Completer<String?>();
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result.complete(
            await showPhotoSourceDialog(context, title: 'Photo'),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  AppLocalizations l10n(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(AppDialog).first));

  Future<void> chooseAlbum(WidgetTester tester) async {
    await tester.tap(find.text(l10n(tester).chooseFromAlbumLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('Album: returns the picked photo', (tester) async {
    picker.next = '/tmp/picked.jpg';
    final result = await openDialog(tester);
    await chooseAlbum(tester);

    expect(await result.future, '/tmp/picked.jpg');
  });

  testWidgets('Album cancelled: returns null, shows no error', (tester) async {
    final result = await openDialog(tester);
    await chooseAlbum(tester);

    expect(await result.future, isNull);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('the chooser dismissed: returns null without opening the album', (
    tester,
  ) async {
    final result = await openDialog(tester);
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();

    expect(await result.future, isNull);
    expect(picker.picks, 0);
  });

  testWidgets('Album failing (photo access denied): returns null and shows '
      'the pick-failed dialog', (tester) async {
    picker.error = PlatformException(
      code: 'photo_access_denied',
      message: 'The user did not allow photo access.',
    );
    final result = await openDialog(tester);
    final text = l10n(tester).photoPickFailed;
    await chooseAlbum(tester);

    expect(await result.future, isNull);
    expect(find.text(text), findsOneWidget);
  });

  testWidgets('Album failing after the calling screen is gone: returns null, '
      'no dialog, no error', (tester) async {
    picker.hold = true;
    final result = await openDialog(tester);
    await chooseAlbum(tester);

    await tester.pumpWidget(const SizedBox()); // the caller is gone
    picker.held!.completeError(
      PlatformException(code: 'already_active', message: 'busy'),
    );
    await tester.pumpAndSettle();

    expect(await result.future, isNull);
    expect(tester.takeException(), isNull);
    expect(find.byType(AppDialog), findsNothing);
  });
}
