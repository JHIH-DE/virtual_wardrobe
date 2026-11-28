import 'package:flutter/material.dart';

import '../models/admin_models.dart';

class StatusChip extends StatelessWidget {
  final PublishStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final published = status == PublishStatus.published;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: published
            ? Colors.green.shade50
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: published ? Colors.green.shade300 : scheme.outlineVariant,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          color: published ? Colors.green.shade800 : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
