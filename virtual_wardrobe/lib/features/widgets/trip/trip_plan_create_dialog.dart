import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/trip_plan.dart';
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
  String _selectedPurpose = 'Leisure Travel';
  final Map<String, String> _purposeOptions = kTripPurposeOptions;

  @override
  void dispose() {
    _tripNameController.dispose();
    _legsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AppDialog(
        title: 'New Trip',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: _tripNameController, label: 'Trip Name'),
            const SizedBox(height: 16),
            TripLegsEditor(legsNotifier: _legsNotifier),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedPurpose,
              decoration: appInputDecoration(
                label: 'Trip Purpose',
                prefixIcon: const Icon(
                  Icons.flight_takeoff,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              items: _purposeOptions.keys
                  .map(
                    (label) =>
                        DropdownMenuItem(value: label, child: Text(label)),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedPurpose = v);
              },
            ),
          ],
        ),
        primaryLabel: 'Create',
        onPrimary: _submit,
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(context),
      ),
    );
  }

  void _submit() {
    if (_tripNameController.text.isEmpty || _legsNotifier.value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    Navigator.pop(
      context,
      TripPlan(
        id: '',
        name: _tripNameController.text,
        legs: _legsNotifier.value,
        purpose: _purposeOptions[_selectedPurpose]!,
      ),
    );
  }
}
