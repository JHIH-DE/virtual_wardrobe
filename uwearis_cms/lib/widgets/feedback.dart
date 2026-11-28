import 'package:flutter/material.dart';

import '../api/api_client.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 480,
      ),
    );
}

String errorText(Object error) => switch (error) {
  ApiError(:final message, :final statusCode, :final requestId)
      when statusCode >= 500 && requestId != null =>
    '$message\n回報問題時請附上 request id：$requestId',
  ApiError(:final message) => message,
  _ => '連線失敗，請確認後端有在執行（$error）',
};

Future<void> showErrorDialog(
  BuildContext context,
  Object error, {
  String title = '操作失敗',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(errorText(error)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('好'),
        ),
      ],
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? body,
  String confirmLabel = '確定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Asks before leaving a form with unsaved edits.
Future<bool> confirmDiscard(BuildContext context) => confirm(
  context,
  title: '放棄未儲存的修改？',
  body: '離開後，這次的修改不會保留。',
  confirmLabel: '放棄修改',
  destructive: true,
);
