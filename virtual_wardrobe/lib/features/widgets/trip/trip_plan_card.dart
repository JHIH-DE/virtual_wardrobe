import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/trip_plan.dart';
import '../common/app_dialog.dart';
import 'trip_legs_editor.dart';

enum _TripCardAction { editName, editLegs, editPurpose, delete }

class TripPlanCard extends StatelessWidget {
  final TripPlan trip;
  final VoidCallback onTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<List<TripLeg>> onLegsChanged;
  final ValueChanged<String> onPurposeChanged;
  final VoidCallback onDelete;

  const TripPlanCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onNameChanged,
    required this.onLegsChanged,
    required this.onPurposeChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${DateFormat('MMM d').format(trip.dateRange.start)} - "
        "${DateFormat('MMM d, yyyy').format(trip.dateRange.end)}";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip.name,
                    style: AppTextStyle.bold24.copyWith(color: Colors.white),
                  ),
                ),
                PopupMenuButton<_TripCardAction>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (action) => _handleAction(context, action),
                  itemBuilder: (context) => [
                    _menuItem(
                      _TripCardAction.editName,
                      Image.asset(
                        'assets/images/edit.png',
                        width: 20,
                        height: 20,
                      ),
                      'Edit Trip Name',
                    ),
                    _menuItem(
                      _TripCardAction.editLegs,
                      const Icon(Icons.map_outlined, color: AppColors.primary),
                      'Edit Trip Legs',
                    ),
                    _menuItem(
                      _TripCardAction.editPurpose,
                      const Icon(
                        Icons.flight_takeoff,
                        color: AppColors.primary,
                      ),
                      'Edit Trip Purpose',
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: _TripCardAction.delete,
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 12),
                          Text(
                            'Delete Trip',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.locationSummary,
                    style: AppTextStyle.regular16.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: AppTextStyle.regular16.copyWith(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "View Plan",
                  style: AppTextStyle.regular12.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_TripCardAction> _menuItem(
    _TripCardAction value,
    Widget icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [icon, const SizedBox(width: 12), Text(label)],
      ),
    );
  }

  void _handleAction(BuildContext context, _TripCardAction action) {
    switch (action) {
      case _TripCardAction.editName:
        _editName(context);
        break;
      case _TripCardAction.editLegs:
        _editLegs(context);
        break;
      case _TripCardAction.editPurpose:
        _editPurpose(context);
        break;
      case _TripCardAction.delete:
        _confirmDelete(context);
        break;
    }
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: trip.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Edit Trip Name',
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter trip name',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null || result.isEmpty || result == trip.name) return;
    onNameChanged(result);
  }

  Future<void> _editLegs(BuildContext context) async {
    final legsNotifier = ValueNotifier<List<TripLeg>>(List.of(trip.legs));
    final result = await showDialog<List<TripLeg>>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Edit Trip Legs',
        content: TripLegsEditor(legsNotifier: legsNotifier),
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, legsNotifier.value),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    legsNotifier.dispose();

    if (result == null || result.isEmpty) return;
    onLegsChanged(result);
  }

  Future<void> _editPurpose(BuildContext context) async {
    final currentLabel = kTripPurposeOptions.entries
        .firstWhere(
          (e) => e.value == trip.purpose,
          orElse: () => kTripPurposeOptions.entries.first,
        )
        .key;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Edit Trip Purpose',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final label in kTripPurposeOptions.keys)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: label == currentLabel
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, label),
              ),
          ],
        ),
        primaryLabel: 'Cancel',
        onPrimary: () => Navigator.pop(ctx),
      ),
    );

    if (result == null || result == currentLabel) return;
    final rawValue = kTripPurposeOptions[result];
    if (rawValue != null) onPurposeChanged(rawValue);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Delete Trip',
        body: 'Are you sure you want to delete this trip?',
        primaryLabel: 'Delete',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed == true) onDelete();
  }
}
