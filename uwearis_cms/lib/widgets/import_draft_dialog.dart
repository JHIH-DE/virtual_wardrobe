import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/story_draft.dart';

/// Pastes a story written outside the CMS (format: backend
/// docs/magazine_cms.md「匯入草稿」); returns it as an unsaved draft in
/// [issueId], or null when cancelled.
Future<StoryDraft?> showImportDraftDialog(
  BuildContext context, {
  required int issueId,
}) => showDialog<StoryDraft>(
  context: context,
  builder: (_) => _ImportDialog(issueId: issueId),
);

class _ImportDialog extends StatefulWidget {
  final int issueId;
  const _ImportDialog({required this.issueId});

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final draft = StoryDraft.fromImport(
        jsonDecode(_text.text),
        issueId: widget.issueId,
      );
      Navigator.pop(context, draft);
    } on FormatException catch (e) {
      setState(() => _error = '讀不懂這段內容：${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('匯入草稿'),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '貼上文章的 JSON（格式見後端 docs/magazine_cms.md「匯入草稿」）。'
              '匯入後會開成一篇還沒儲存的草稿，補上圖片再儲存。',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 10,
              maxLines: 16,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText:
                    '{ "format": "story", "slug": "...", "pages": [ ... ] }',
                errorText: _error,
                errorMaxLines: 4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('匯入')),
      ],
    );
  }
}
