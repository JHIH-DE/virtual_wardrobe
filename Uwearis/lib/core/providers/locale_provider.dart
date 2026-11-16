import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_service.dart';
import '../utils/debug_log.dart';

/// User's explicit language override. Null means "follow the system
/// locale" (gen_l10n's default resolution, falling back to English).
final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale?> {
  static const _prefsKey = 'app_locale';

  @override
  Locale? build() {
    _loadSaved();
    return null;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code == null) return;
    state = _localeFromCode(code);
  }

  Future<void> _backendSync = Future.value();

  /// Completes once the latest switch reached the backend (or failed to).
  /// Never throws.
  Future<void> get backendSynced => _backendSync;

  // The backend `locale` confirmed for the current account. Static: the
  // sign-out path ([forgetBackendLocale]) has no provider container.
  static String? _confirmedCode;
  static int _generation = 0;
  static Future<bool>? _inFlight;
  static String? _inFlightCode;

  /// The backend's `Locale` for a displayed app locale.
  static String apiLocaleFor(Locale displayed) =>
      displayed.languageCode == 'zh' ? 'zh-TW' : 'en';

  /// Call at session end, so the next account's locale is pushed again.
  static void forgetBackendLocale() {
    _generation++;
    _confirmedCode = null;
    _inFlight = null;
    _inFlightCode = null;
  }

  /// The backend only learns a locale from [setLocale], so a user following
  /// the system — or one signed in on a device whose saved choice predates
  /// the account — still has its default (`en`). Call with the displayed
  /// locale's [apiLocaleFor] before reading backend-labelled data. Pushes it
  /// unless the backend already confirmed it this session; a failed push is
  /// retried on the next call. Never throws.
  Future<void> ensureBackendLocale(String apiCode) async {
    if (_confirmedCode == apiCode) return;
    final pending = _inFlightCode == apiCode ? _inFlight : null;
    await (pending ?? _push(apiCode));
  }

  Future<bool> _push(String apiCode) {
    final generation = _generation;
    late final Future<bool> push;
    push = _syncToBackend(apiCode).then((ok) {
      if (identical(_inFlight, push)) {
        _inFlight = null;
        _inFlightCode = null;
      }
      if (ok && generation == _generation) _confirmedCode = apiCode;
      return ok;
    });
    _inFlight = push;
    _inFlightCode = apiCode;
    return push;
  }

  Future<void> setLocale(Locale? locale) async {
    // Started before the state change, so providers rebuilt by it can wait
    // on [backendSynced].
    final sync = _push(apiLocaleFor(locale ?? _systemLocale()));
    _backendSync = sync;
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _codeFor(locale));
    }
    await sync;
  }

  // Best-effort: sets the language of AI-generated text, the weather place
  // name and adjustment labels. A failure doesn't undo the local switch.
  static Future<bool> _syncToBackend(String apiCode) async {
    try {
      await ProfileService().updateMyProfile(locale: apiCode);
      return true;
    } catch (e) {
      debugLog('LocaleNotifier: failed to sync locale to backend: $e');
      return false;
    }
  }

  static String _codeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  static Locale _localeFromCode(String code) {
    final parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  /// The displayed locale when following the system: any zh device locale
  /// maps to zh-TW, everything else to en.
  static Locale _systemLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'zh'
        ? const Locale('zh', 'TW')
        : const Locale('en');
  }
}
