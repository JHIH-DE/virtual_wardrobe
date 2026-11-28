import 'package:flutter/material.dart';

import '../models/story_draft.dart';

/// One text in both languages, edited side by side.
class BilingualField extends StatefulWidget {
  final String label;
  final Bilingual value;
  final VoidCallback onChanged;
  final bool multiline;
  final int? maxLength;

  const BilingualField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.multiline = false,
    this.maxLength,
  });

  @override
  State<BilingualField> createState() => _BilingualFieldState();
}

class _BilingualFieldState extends State<BilingualField> {
  late final _zh = TextEditingController(text: widget.value.zhTw);
  late final _en = TextEditingController(text: widget.value.en);

  @override
  void dispose() {
    _zh.dispose();
    _en.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String language,
    ValueChanged<String> set,
  ) {
    return TextField(
      controller: controller,
      minLines: widget.multiline ? 3 : 1,
      maxLines: widget.multiline ? null : 1,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: '${widget.label}（$language）',
        border: const OutlineInputBorder(),
        counterText: widget.maxLength == null ? null : '',
        isDense: true,
      ),
      onChanged: (text) {
        set(text);
        widget.onChanged();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zh = _field(_zh, '中文', (t) => widget.value.zhTw = t);
        final en = _field(_en, 'English', (t) => widget.value.en = t);
        if (constraints.maxWidth < 520) {
          return Column(children: [zh, const SizedBox(height: 8), en]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: zh),
            const SizedBox(width: 12),
            Expanded(child: en),
          ],
        );
      },
    );
  }
}
