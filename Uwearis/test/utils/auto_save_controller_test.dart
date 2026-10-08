import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/auto_save_controller.dart';

/// Records every save and lets the test decide when each one completes.
class _FakeSaver {
  final List<Completer<void>> pending = [];
  int calls = 0;

  Future<void> save() {
    calls++;
    final c = Completer<void>();
    pending.add(c);
    return c.future;
  }

  void completeNext() => pending.removeAt(0).complete();

  void failNext([Object error = 'boom']) =>
      pending.removeAt(0).completeError(error);
}

void main() {
  group('AutoSaveController', () {
    test('requestSave saves immediately', () async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save);

      ctrl.requestSave();
      expect(saver.calls, 1);
      expect(ctrl.isSaving, isTrue);
      expect(ctrl.hasPendingChanges, isTrue);

      saver.completeNext();
      await pumpEventQueue();
      expect(ctrl.isSaving, isFalse);
      expect(ctrl.hasPendingChanges, isFalse);
    });

    test('changes during an in-flight save coalesce into exactly one '
        'follow-up save, started only after the first finishes', () async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save);

      ctrl.requestSave();
      ctrl.requestSave();
      ctrl.requestSave();
      expect(saver.calls, 1);

      saver.completeNext();
      await pumpEventQueue();
      expect(saver.calls, 2);

      saver.completeNext();
      await pumpEventQueue();
      expect(saver.calls, 2);
      expect(ctrl.hasPendingChanges, isFalse);
    });

    test('a failed save is not retried automatically and reports the error '
        'once', () async {
      final saver = _FakeSaver();
      final errors = <Object>[];
      final ctrl = AutoSaveController(onSave: saver.save, onError: errors.add);

      ctrl.requestSave();
      saver.failNext('network down');
      await pumpEventQueue();

      expect(errors, ['network down']);
      expect(ctrl.hasFailed, isTrue);
      expect(ctrl.hasPendingChanges, isTrue);
      expect(saver.calls, 1);
    });

    test(
      'a failure drops any queued follow-up save until the next request',
      () async {
        final saver = _FakeSaver();
        final ctrl = AutoSaveController(onSave: saver.save);

        ctrl.requestSave();
        ctrl.requestSave(); // queued behind the first
        saver.failNext();
        await pumpEventQueue();
        expect(saver.calls, 1);

        // Retry (or any new change) clears the failure and saves the latest.
        ctrl.requestSave();
        expect(ctrl.hasFailed, isFalse);
        expect(saver.calls, 2);
        saver.completeNext();
        await pumpEventQueue();
        expect(ctrl.hasPendingChanges, isFalse);
      },
    );

    test('a synchronous throw from onSave is treated as a failure', () async {
      final errors = <Object>[];
      final ctrl = AutoSaveController(
        onSave: () => throw StateError('sync'),
        onError: errors.add,
      );

      ctrl.requestSave();
      await pumpEventQueue();
      expect(errors.single, isA<StateError>());
      expect(ctrl.isSaving, isFalse);
      expect(ctrl.hasFailed, isTrue);
    });

    group('flush', () {
      test('resolves true immediately when nothing is pending', () async {
        final saver = _FakeSaver();
        final ctrl = AutoSaveController(onSave: saver.save);
        expect(await ctrl.flush(), isTrue);
        expect(saver.calls, 0);
      });

      test('waits for the in-flight save and its follow-up', () async {
        final saver = _FakeSaver();
        final ctrl = AutoSaveController(onSave: saver.save);

        ctrl.requestSave();
        ctrl.requestSave();
        var done = false;
        final result = ctrl.flush().then((ok) {
          done = true;
          return ok;
        });

        saver.completeNext();
        await pumpEventQueue();
        expect(done, isFalse);
        saver.completeNext();
        expect(await result, isTrue);
        expect(saver.calls, 2);
      });

      test('retries a previously failed change', () async {
        final saver = _FakeSaver();
        final ctrl = AutoSaveController(onSave: saver.save);

        ctrl.requestSave();
        saver.failNext();
        await pumpEventQueue();

        final result = ctrl.flush();
        expect(saver.calls, 2);
        saver.completeNext();
        expect(await result, isTrue);
        expect(ctrl.hasFailed, isFalse);
      });

      test('resolves false when the save fails, reporting it through '
          'lastError instead of onError', () async {
        final saver = _FakeSaver();
        final errors = <Object>[];
        final ctrl = AutoSaveController(
          onSave: saver.save,
          onError: errors.add,
        );

        ctrl.requestSave();
        final result = ctrl.flush();
        saver.failNext('offline');
        expect(await result, isFalse);
        expect(ctrl.hasPendingChanges, isTrue);
        expect(ctrl.lastError, 'offline');
        expect(errors, isEmpty);
      });
    });

    test('lastError clears once a new save is requested', () async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save);

      ctrl.requestSave();
      saver.failNext('offline');
      await pumpEventQueue();
      expect(ctrl.lastError, 'offline');

      ctrl.requestSave();
      expect(ctrl.lastError, isNull);
    });

    test('notifies listeners only when hasPendingChanges flips', () async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save);
      final seen = <bool>[];
      ctrl.addListener(() => seen.add(ctrl.hasPendingChanges));

      ctrl.requestSave();
      ctrl.requestSave(); // already pending — no extra notification
      expect(seen, [true]);

      saver.completeNext();
      await pumpEventQueue();
      saver.completeNext(); // the coalesced follow-up
      await pumpEventQueue();
      expect(seen, [true, false]);

      ctrl.requestSave();
      saver.failNext(); // still pending after a failure
      await pumpEventQueue();
      expect(seen, [true, false, true]);
    });

    test('dispose stops follow-up saves and error callbacks', () async {
      final saver = _FakeSaver();
      final errors = <Object>[];
      final ctrl = AutoSaveController(onSave: saver.save, onError: errors.add);

      ctrl.requestSave();
      ctrl.requestSave(); // would normally queue a follow-up
      ctrl.dispose();
      saver.failNext();
      await pumpEventQueue();

      expect(errors, isEmpty);
      expect(saver.calls, 1);
      ctrl.requestSave();
      expect(saver.calls, 1);
    });
  });

  group('AutoSaveController debounce', () {
    const debounce = Duration(milliseconds: 800);

    testWidgets('scheduleSave waits for a quiet period, restarting on each '
        'change', (tester) async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save, debounce: debounce);

      ctrl.scheduleSave();
      await tester.pump(const Duration(milliseconds: 500));
      ctrl.scheduleSave();
      await tester.pump(const Duration(milliseconds: 500));
      expect(saver.calls, 0);
      expect(ctrl.hasPendingChanges, isTrue);

      await tester.pump(const Duration(milliseconds: 300));
      expect(saver.calls, 1);
      saver.completeNext();
      await tester.pump();
      expect(ctrl.hasPendingChanges, isFalse);
    });

    testWidgets('requestSave skips a pending debounce', (tester) async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save, debounce: debounce);

      ctrl.scheduleSave();
      ctrl.requestSave();
      expect(saver.calls, 1);

      saver.completeNext();
      await tester.pump(debounce * 2);
      expect(saver.calls, 1);
    });

    testWidgets('flush skips a pending debounce', (tester) async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save, debounce: debounce);

      ctrl.scheduleSave();
      final result = ctrl.flush();
      expect(saver.calls, 1);
      saver.completeNext();
      await tester.pump();
      expect(await result, isTrue);
    });

    testWidgets('a change debounced during an in-flight save waits for its '
        'own timer instead of riding the in-flight one', (tester) async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save, debounce: debounce);

      ctrl.requestSave();
      ctrl.scheduleSave();
      saver.completeNext();
      await tester.pump();
      expect(saver.calls, 1);

      await tester.pump(debounce);
      expect(saver.calls, 2);
      saver.completeNext();
      await tester.pump();
      expect(ctrl.hasPendingChanges, isFalse);
    });

    testWidgets('dispose cancels a pending debounce', (tester) async {
      final saver = _FakeSaver();
      final ctrl = AutoSaveController(onSave: saver.save, debounce: debounce);

      ctrl.scheduleSave();
      ctrl.dispose();
      await tester.pump(debounce * 2);
      expect(saver.calls, 0);
    });
  });
}
