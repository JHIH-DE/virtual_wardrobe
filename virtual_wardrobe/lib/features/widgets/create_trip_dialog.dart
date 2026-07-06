import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../data/trip_plan.dart';
import '../location_picker_page.dart';
import 'app_text_field.dart';
import 'bottom_action_button.dart';

class CreateTripDialog extends StatefulWidget {
  const CreateTripDialog({super.key});

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  final TextEditingController _tripNameController = TextEditingController();
  DateTimeRange? _dateRange;
  LocationResult? _location;
  String _selectedStyle = 'Casual';
  final List<String> _styleOptions = [
    'Casual',
    'Formal',
    'Street',
    'Vacation',
    'Sporty',
    'Chic',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
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
            value: _selectedStyle,
            decoration: appInputDecoration(
              label: 'Default Style',
              prefixIcon: const Icon(
                Icons.style,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            items: _styleOptions
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedStyle = v);
            },
          ),
          const SizedBox(height: 24),
          BottomActionButton(
            label: 'Create',
            onPressed: _saveTrip,
            buttonColor: AppColors.primary,
            textColor: Colors.white,
            panelColor: Colors.transparent,
            showShadow: false,
            panelPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
      ],
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

  void _saveTrip() {
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
        id: DateTime.now().toIso8601String(),
        name: _tripNameController.text,
        dateRange: _dateRange!,
        location: _location!,
        style: _selectedStyle,
      ),
    );
  }
}
