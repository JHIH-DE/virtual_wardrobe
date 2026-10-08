import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives auto-save for a page that edits an *existing* record (Garment
/// Details in edit mode, Account, Lifestyle) — creating a new record keeps
/// an explicit Save/Add button instead.
///
/// The page stays the single source of truth: [onSave] reads the page's
/// current state and persists all of it, so whichever save runs last always
/// carries the latest values. The controller only decides *when* to call it:
///
/// - At most one save is in flight. A change that arrives meanwhile marks
///   the controller dirty, and exactly one follow-up save runs once the
///   current one finishes — however many changes piled up — so a slow older
///   PATCH can never land after (and overwrite) a newer one.
/// - [requestSave] saves as soon as possible (pickers, chips, dates — a
///   discrete choice is already final). [scheduleSave] waits for [debounce]
///   of quiet first (a text field mid-typing); the page should also call
///   [requestSave] on blur/submit so leaving the field never waits.
/// - A failed save is not retried automatically: [hasFailed] turns true and
///   [onError] is called once so the page can offer a retry. The next
///   [requestSave] / [scheduleSave] (including a retry) clears it.
/// - [flush] is for leaving the page: it pushes any pending change
///   immediately and resolves once nothing is left in flight. A failure
///   during a flush is reported through its result and [lastError] instead
///   of [onError], so the leave prompt doesn't stack on an error dialog.
///
/// Listeners are notified whenever [hasPendingChanges] flips, which is what
/// a `PopScope.canPop` needs to rebuild on.
///
/// Validation is the page's job — an invalid field should simply not reach
/// [onSave]'s payload (or the page shouldn't request a save for it).
class AutoSaveController extends ChangeNotifier {
  AutoSaveController({
    required this.onSave,
    this.onError,
    this.debounce = const Duration(milliseconds: 800),
  });

  final Future<void> Function() onSave;
  final void Function(Object error)? onError;
  final Duration debounce;

  Timer? _debounceTimer;
  Future<void>? _inFlight;
  bool _dirty = false;
  bool _failed = false;
  bool _disposed = false;
  int _flushDepth = 0;
  Object? _lastError;

  bool get isSaving => _inFlight != null;

  bool get hasFailed => _failed;

  /// The error from the most recent failed save, or `null` once a later save
  /// is requested.
  Object? get lastError => _lastError;

  /// True while a change hasn't been persisted yet — waiting on the debounce,
  /// in flight, or left behind by a failed save.
  bool get hasPendingChanges => _dirty || _inFlight != null || _failed;

  void requestSave() {
    if (_disposed) return;
    _track(() {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      _markDirty();
      _drain();
    });
  }

  void scheduleSave() {
    if (_disposed) return;
    _track(() {
      _markDirty();
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounce, () {
        _debounceTimer = null;
        _drain();
      });
    });
  }

  /// Saves any pending change now and waits until nothing is in flight.
  /// Returns whether everything ended up persisted — `false` means the last
  /// save failed and the page should ask before discarding.
  Future<bool> flush() async {
    if (_disposed) return !_failed;
    _flushDepth++;
    try {
      _track(() {
        _debounceTimer?.cancel();
        _debounceTimer = null;
        // A failed change is still dirty; retrying it here is what "leave"
        // means.
        if (_failed) _markDirty();
        _drain();
      });
      while (_inFlight != null) {
        await _inFlight;
      }
      return !_failed && !_dirty;
    } finally {
      _flushDepth--;
    }
  }

  void _markDirty() {
    _dirty = true;
    _failed = false;
    _lastError = null;
  }

  /// Runs [change] and notifies listeners if it flipped [hasPendingChanges].
  void _track(void Function() change) {
    final before = hasPendingChanges;
    change();
    if (!_disposed && hasPendingChanges != before) notifyListeners();
  }

  void _drain() {
    if (_inFlight != null || !_dirty || _debounceTimer != null) return;
    _inFlight = _runSaves();
  }

  Future<void> _runSaves() async {
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        try {
          // Future.sync so a synchronous throw still lands after the first
          // await — _runSaves' finally must not run before _drain has
          // stored _inFlight.
          await Future.sync(onSave);
        } catch (e) {
          if (_disposed) return;
          // Keep the change marked unsaved so flush()/leave can see it.
          _dirty = true;
          _failed = true;
          _lastError = e;
          if (_flushDepth == 0) onError?.call(e);
          return;
        }
        // A newer change still waiting on its debounce gets its own save
        // when the timer fires — don't jump the gun here.
        if (_debounceTimer != null) return;
      }
    } finally {
      _track(() => _inFlight = null);
    }
  }

  /// Drops any pending debounce. A save already in flight finishes, but
  /// [onError] is no longer called and no follow-up save starts.
  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    super.dispose();
  }
}
