import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/trip_plan.dart';
import '../../../data/trip_purpose.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/trip_purpose_localization.dart';
import '../common/app_dialog.dart';
import '../common/app_text_field.dart';
import 'trip_legs_editor.dart';

class TripPlanCreateDialog extends StatefulWidget {
  const TripPlanCreateDialog({super.key});

  @override
  State<TripPlanCreateDialog> createState() => _TripPlanCreateDialogState();
}

class _TripPlanCreateDialogState extends State<TripPlanCreateDialog> {
  final TextEditingController _tripNameController = TextEditingController();
  final ValueNotifier<List<TripLeg>> _legsNotifier = ValueNotifier([]);
  TripPurpose _selectedPurpose = TripPurpose.leisureTravel;

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
            const SizedBox(height: 16),
            DropdownButtonFormField<TripPurpose>(
              value: _selectedPurpose,
              decoration: appInputDecoration(
                label: l10n.tripPurposeLabel,
                prefixIcon: const Icon(
                  Icons.flight_takeoff,
                  color: AppColors.icon,
                  size: 20,
                ),
              ),
              items: TripPurpose.values
                  .map(
                    (purpose) => DropdownMenuItem(
                      value: purpose,
                      child: Text(purpose.localizedLabel(context)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedPurpose = v);
              },
            ),
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
      TripPlan(
        id: '',
        name: _tripNameController.text,
        legs: _legsNotifier.value,
        purpose: _selectedPurpose.apiValue,
      ),
    );
  }
}
