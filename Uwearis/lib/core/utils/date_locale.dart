import 'package:flutter/widgets.dart';

/// Locale for `DateFormat`. intl's `zh` date symbols are Simplified; the
/// app's Chinese is Traditional, so any Chinese maps to `zh_TW`.
String dateLocaleOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  return locale.languageCode == 'zh' ? 'zh_TW' : locale.languageCode;
}
