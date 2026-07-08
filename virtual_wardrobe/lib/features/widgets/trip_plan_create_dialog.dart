import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../data/trip_plan.dart';
import '../location_picker_page.dart';
import 'app_text_field.dart';
import 'bottom_action_button.dart';

class TripPlanCreateDialog extends StatefulWidget {
  const TripPlanCreateDialog({super.key});

  @override
  State<TripPlanCreateDialog> createState() => _TripPlanCreateDialogState();
}

class _TripPlanCreateDialogState extends State<TripPlanCreateDialog> {
  final TextEditingController _tripNameController = TextEditingController();
  DateTimeRange? _dateRange;
  LocationResult? _location;
  String _selectedPurpose = 'Leisure Travel';
  final Map<String, String> _purposeOptions = const {
    'Leisure Travel': 'leisure_travel',
    'Business Trip': 'business_trip',
    'Family Trip': 'family_trip',
    'Outdoor Trip': 'outdoor_trip',
    'City Trip': 'city_trip',
    'Resort / Vacation': 'resort_vacation',
    'Mixed': 'mixed',
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "New Trip",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: _tripNameController, label: 'Trip Name'),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dateRange == null
                    ? "Select Dates"
                    : "${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}",
              ),
              leading: const Icon(
                Icons.calendar_today,
                color: AppColors.primary,
              ),
              onTap: _pickDateRange,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _location == null ? "Select Location" : _location!.name,
              ),
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              onTap: _pickLocation,
            ),
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
            const SizedBox(height: 24),
            BottomActionButton(
              label: 'Create',
              onPressed: _submit,
              buttonColor: AppColors.primary,
              textColor: Colors.white,
              panelColor: Colors.transparent,
              showShadow: false,
              panelPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            BottomActionButton(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
              buttonColor: AppColors.primary,
              textColor: Colors.white,
              panelColor: Colors.transparent,
              showShadow: false,
              panelPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (result != null) setState(() => _dateRange = result);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result is LocationResult) setState(() => _location = result);
  }

  void _submit() {
    if (_tripNameController.text.isEmpty ||
        _dateRange == null ||
        _location == null) {
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
        dateRange: _dateRange!,
        location: _location!,
        purpose: _purposeOptions[_selectedPurpose]!,
      ),
    );
  }
}
