import 'package:flutter/material.dart';

import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/fields/app_text_field.dart';
import '../common/overlays/app_dialog.dart';
import 'trip_legs_editor.dart';

class TripCreateDialog extends StatefulWidget {
  const TripCreateDialog({super.key});

  @override
  State<TripCreateDialog> createState() => _TripCreateDialogState();
}

class _TripCreateDialogState extends State<TripCreateDialog> {
  final TextEditingController _tripNameController = TextEditingController();
  final ValueNotifier<List<TripLeg>> _legsNotifier = ValueNotifier([]);

  @override
  void dispose() {
    _tripNameController.dispose();
    _legsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: AppDialog(
        title: l10n.newTrip,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _tripNameController,
              label: l10n.tripNameLabel,
            ),
            const SizedBox(height: 16),
            TripLegsEditor(legsNotifier: _legsNotifier),
          ],
        ),
        primaryLabel: l10n.create,
        onPrimary: _submit,
        secondaryLabel: l10n.cancel,
        onSecondary: () => Navigator.pop(context),
      ),
    );
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_tripNameController.text.isEmpty || _legsNotifier.value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.fillAllFieldsError)));
      return;
    }
    Navigator.pop(
      context,
      Trip(
        id: '',
        name: _tripNameController.text,
        legs: _legsNotifier.value,
        activities: const [],
      ),
    );
  }
}
