import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/admin_user.dart';
import 'cms_scope.dart';
import 'feedback.dart';

/// Permanently deletes a user once the admin types DELETE; pops true when the
/// user is gone. The dialog names the account (id, email, sign-in) because one
/// email can have both a Google and an Apple account.
class DeleteUserDialog extends StatefulWidget {
  final AdminUser user;
  const DeleteUserDialog({super.key, required this.user});

  @override
  State<DeleteUserDialog> createState() => _DeleteUserDialogState();
}

class _DeleteUserDialogState extends State<DeleteUserDialog> {
  static const _phrase = 'DELETE';

  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _matches => _confirm.text.trim() == _phrase;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CmsScope.read(
        context,
      ).deleteUser(widget.user.id, confirmUserId: widget.user.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiError catch (e) {
      // A resend after an unknown outcome finds the user already gone.
      if (e.errorCode == 'USER_NOT_FOUND') {
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (mounted) {
        setState(
          () => _error = e.errorCode == 'ADMIN_CANNOT_DELETE_SELF'
              ? '${e.message}\n自己的帳號請從 App 刪除。'
              : e.message,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${errorText(e)}\n不確定有沒有刪除：可以再按一次確認。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    return AlertDialog(
      title: const Text('永久刪除這位使用者？'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID：${widget.user.id}'),
                  Text('Email：${widget.user.email}'),
                  Text('登入方式：${authProviderLabel(widget.user.authProvider)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '會立即刪除這位使用者的所有資料與圖片：衣物、穿搭、行程、點數紀錄、照片與個人資料。'
              '對方會被登出。',
            ),
            const SizedBox(height: 8),
            Text(
              '這個動作無法復原。',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            const Text('請輸入 $_phrase 以確認：'),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              autofocus: true,
              enabled: !_busy,
              decoration: const InputDecoration(
                hintText: _phrase,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (_matches && !_busy) _delete();
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error),
          onPressed: _matches && !_busy ? _delete : null,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('刪除'),
        ),
      ],
    );
  }
}
