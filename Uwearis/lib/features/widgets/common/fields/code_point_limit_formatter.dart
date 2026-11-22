import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Caps a field at [max] Unicode code points — the unit the backend's
/// length limits (Pydantic `max_length`) count, so a field capped here can't
/// be rejected with 422 for its length. `LengthLimitingTextInputFormatter`
/// counts grapheme clusters instead, which an emoji or a combining mark
/// slips past. Cuts only between graphemes, and waits for an IME
/// composition to end like the built-in one does.
class CodePointLimitFormatter extends TextInputFormatter {
  final int max;

  const CodePointLimitFormatter(this.max);

  /// [text] cut to [max] code points, at a grapheme boundary — for a value
  /// set in code (e.g. an AI suggestion), which skips the formatters.
  static String truncate(String text, int max) {
    if (text.runes.length <= max) return text;
    final kept = StringBuffer();
    var codePoints = 0;
    for (final grapheme in text.characters) {
      final length = grapheme.runes.length;
      if (codePoints + length > max) break;
      kept.write(grapheme);
      codePoints += length;
    }
    return kept.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    if (oldValue.text.runes.length == max && oldValue.selection.isCollapsed) {
      return oldValue;
    }
    final text = truncate(newValue.text, max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: newValue.selection.extentOffset.clamp(0, text.length),
      ),
    );
  }
}
