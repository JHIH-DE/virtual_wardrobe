import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';
import '../models/admin_user.dart';
import '../utils/idempotency_key.dart';
import 'cms_scope.dart';
import 'feedback.dart';

/// Adds or removes points by hand; pops with the updated user.
///
/// One Idempotency-Key per (amount, reason): a resend after a timeout reuses
/// it so the backend adjusts only once. Any answer from the backend settles
/// that attempt, so the next send gets a new key.
class PointsAdjustDialog extends StatefulWidget {
  final AdminUser user;
  final bool add;
  const PointsAdjustDialog({super.key, required this.user, required this.add});

  @override
  State<PointsAdjustDialog> createState() => _PointsAdjustDialogState();
}

class _PointsAdjustDialogState extends State<PointsAdjustDialog> {
  static const _maxAmount = 1000000;

  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _key;
  (int, String)? _keyFor;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _parsedAmount {
    final value = int.tryParse(_amount.text);
    return value == null || value <= 0 || value > _maxAmount ? null : value;
  }

  String get _verb => widget.add ? '加' : '扣';

  Future<void> _submit() async {
    final amount = _parsedAmount;
    final note = _note.text.trim();
    if (amount == null) {
      setState(() => _error = '點數要是 1 到 $_maxAmount 的整數');
      return;
    }
    if (note.isEmpty) {
      setState(() => _error = '請填寫原因');
      return;
    }
    final ok = await confirm(
      context,
      title: '確定替 ${widget.user.email} $_verb $amount 點？',
      body: '原因：$note',
      confirmLabel: '確定$_verb點',
      destructive: !widget.add,
    );
    if (!ok || !mounted) return;

    final delta = widget.add ? amount : -amount;
    if (_keyFor != (delta, note)) {
      _key = newIdempotencyKey();
      _keyFor = (delta, note);
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await CmsScope.read(context).adjustPoints(
        widget.user.id,
        delta: delta,
        note: note,
        idempotencyKey: _key!,
      );
      if (mounted) Navigator.pop(context, user);
    } on ApiError catch (e) {
      _keyFor = null;
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = '${errorText(e)}\n不確定有沒有成功：直接再按一次送出，不會重複調整。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AlertDialog(
      title: Text('$_verb點：${widget.user.email}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('目前餘額 ${widget.user.pointsBalance} 點。手動調整不受每日上限限制。'),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '$_verb幾點',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _note,
              enabled: !_busy,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: '原因（會顯示在使用者的點數紀錄）',
                border: OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('$_verb點'),
        ),
      ],
    );
  }
}
