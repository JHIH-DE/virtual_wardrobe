import 'package:flutter/material.dart';

import '../../../core/services/auth_handler.dart';

/// Centered error message with a retry button. Renders nothing for
/// [AuthExpiredException] since that's handled by the auth-expiry listener
/// at the page level instead.
class ErrorStateWidget extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String retryLabel;

  const ErrorStateWidget({
    super.key,
    required this.error,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    if (error is AuthExpiredException) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(error.toString(), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
