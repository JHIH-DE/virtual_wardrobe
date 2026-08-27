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

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, _codeFor(locale));
    }
    // Best-effort: the backend uses this to decide what language to
    // generate AI outfit text (name/style/season/reasoning), packing
    // advice, etc. in. A failure here shouldn't undo the local switch —
    // it just means AI content stays in whatever language the backend
    // last had until the next successful sync.
    try {
      await ProfileService().updateMyProfile(
        locale: _apiCodeFor(locale ?? _systemLocale()),
      );
    } catch (e) {
      debugLog('LocaleNotifier.setLocale: failed to sync locale to backend: $e');
    }
  }

  static String _codeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  static Locale _localeFromCode(String code) {
    final parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }

  /// BCP-47-style code for the backend (`"zh-TW"`, not this class's own
  /// underscore-joined storage format).
  static String _apiCodeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}-${locale.countryCode}';

  /// Resolves what locale the app is actually displaying when the user
  /// follows the system default (this class's own `null` state) — only
  /// 'zh'/non-'zh' matters since zh-TW and en are the only supported
  /// locales (see AppLocalizations.supportedLocales).
  static Locale _systemLocale() {
    final deviceLocale = PlatformDispatcher.instance.locale;
    return deviceLocale.languageCode == 'zh'
        ? const Locale('zh', 'TW')
        : const Locale('en');
  }
}
