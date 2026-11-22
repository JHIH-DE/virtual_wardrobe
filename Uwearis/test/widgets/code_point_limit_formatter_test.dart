import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/fields/code_point_limit_formatter.dart';

void main() {
  TextEditingValue typed(String text) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  group('truncate', () {
    test('keeps text within the limit as is', () {
      expect(CodePointLimitFormatter.truncate('BEAMS', 5), 'BEAMS');
    });

    test('counts code points and never splits a grapheme', () {
      // 👍🏽 is one grapheme of two code points.
      expect(CodePointLimitFormatter.truncate('👍🏽👍🏽', 3), '👍🏽');
      expect(CodePointLimitFormatter.truncate('abc', 2), 'ab');
    });
  });

  group('formatEditUpdate', () {
    const formatter = CodePointLimitFormatter(4);

    test('cuts an over-long edit to the limit', () {
      final out = formatter.formatEditUpdate(typed(''), typed('abcdef'));
      expect(out.text, 'abcd');
      expect(out.selection.extentOffset, 4);
    });

    test('a field already at the limit keeps its text', () {
      final out = formatter.formatEditUpdate(typed('abcd'), typed('abXcd'));
      expect(out.text, 'abcd');
    });

    test('waits for an IME composition to end', () {
      const composing = TextEditingValue(
        text: 'abcdef',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 4, end: 6),
      );
      expect(formatter.formatEditUpdate(typed('abcd'), composing), composing);
    });
  });
}
