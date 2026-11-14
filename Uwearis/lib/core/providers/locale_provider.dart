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

  Future<void> setLocale(Locale? locale) async {
    // Started before the state change, so providers rebuilt by it can wait
    // on [backendSynced].
    final sync = _syncToBackend(locale);
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

  // Best-effort: sets the language of AI-generated text and of the weather
  // place name. A failure doesn't undo the local switch.
  Future<void> _syncToBackend(Locale? locale) async {
    try {
      await ProfileService().updateMyProfile(
        locale: _apiCodeFor(locale ?? _systemLocale()),
      );
    } catch (e) {
      debugLog(
        'LocaleNotifier.setLocale: failed to sync locale to backend: $e',
      );
    }
  }

  static String _codeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  static Locale _localeFromCode(String code) {
    final parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  /// BCP-47 (`"zh-TW"`), unlike the underscore storage format.
  static String _apiCodeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}-${locale.countryCode}';

  /// The displayed locale when following the system: any zh device locale
  /// maps to zh-TW, everything else to en.
  static Locale _systemLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'zh'
        ? const Locale('zh', 'TW')
        : const Locale('en');
  }
}
