import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  }

  static String _codeFor(Locale locale) => locale.countryCode == null
      ? locale.languageCode
      : '${locale.languageCode}_${locale.countryCode}';

  static Locale _localeFromCode(String code) {
    final parts = code.split('_');
    return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
  }
}
