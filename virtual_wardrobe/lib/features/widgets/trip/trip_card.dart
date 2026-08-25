import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/trip_activity_localization.dart';
import '../common/fields/app_text_field.dart';
import '../common/overlays/app_dialog.dart';
import 'trip_legs_editor.dart';

enum _TripCardAction { editName, editLegs, editActivities, delete }

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<List<TripLeg>> onLegsChanged;
  final ValueChanged<List<String>> onActivitiesChanged;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onNameChanged,
    required this.onLegsChanged,
    required this.onActivitiesChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr =
        "${DateFormat('MMM d').format(trip.dateRange.start)} - "
        "${DateFormat('MMM d, yyyy').format(trip.dateRange.end)}";

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(trip.name, style: AppTextStyle.bold24),
                    ),
                    Transform.translate(
                      offset: const Offset(18, 0),
                      child: PopupMenuButton<_TripCardAction>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          color: AppColors.icon,
                        ),
                        color: AppColors.surface,
                        elevation: 4,
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
                            l10n.editTripName,
                          ),
                          _menuItem(
                            _TripCardAction.editLegs,
                            const Icon(
                              Icons.map_outlined,
                              color: AppColors.icon,
                            ),
                            l10n.editDestinations,
                          ),
                          _menuItem(
                            _TripCardAction.editActivities,
                            const Icon(
                              Icons.flight_takeoff,
                              color: AppColors.icon,
                            ),
                            l10n.editTripActivities,
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: _TripCardAction.delete,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.icon,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  l10n.deleteTrip,
                                  style: AppTextStyle.regular14.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.icon,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trip.locationSummary,
                        style: AppTextStyle.regular16,
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
                      color: AppColors.icon,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(dateStr, style: AppTextStyle.regular16),
                  ],
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColors.dividerSubtle,
          ),

          // Full-width "View Plan" area
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppColors.interactiveArea,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    l10n.viewPlan,
                    style: AppTextStyle.regular12.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.icon,
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
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
        children: [
          icon,
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyle.regular14.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
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
      case _TripCardAction.editActivities:
        _editActivities(context);
        break;
      case _TripCardAction.delete:
        _confirmDelete(context);
        break;
    }
  }

  Future<void> _editName(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: trip.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.editTripName,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.bold16,
          decoration: appInputDecoration(hint: l10n.enterTripName),
        ),
        primaryLabel: l10n.save,
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: l10n.cancel,
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null || result.isEmpty || result == trip.name) return;
    onNameChanged(result);
  }

  Future<void> _editLegs(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final legsNotifier = ValueNotifier<List<TripLeg>>(List.of(trip.legs));
    final result = await showDialog<List<TripLeg>>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.editDestinations,
        content: TripLegsEditor(legsNotifier: legsNotifier),
        primaryLabel: l10n.save,
        onPrimary: () => Navigator.pop(ctx, legsNotifier.value),
        secondaryLabel: l10n.cancel,
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    legsNotifier.dispose();

    if (result == null || result.isEmpty) return;
    onLegsChanged(result);
  }

  Future<void> _editActivities(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = trip.activities
        .map(tripActivityFromApiValue)
        .whereType<TripActivity>()
        .toSet();

    final result = await showDialog<Set<TripActivity>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AppDialog(
          title: l10n.editTripActivities,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final activity in TripActivity.values)
                CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.accent,
                  value: selected.contains(activity),
                  title: Text(
                    activity.localizedLabel(context),
                    style: AppTextStyle.regular16,
                  ),
                  onChanged: (checked) => setDialogState(() {
                    if (checked == true) {
                      selected.add(activity);
                    } else {
                      selected.remove(activity);
                    }
                  }),
                ),
            ],
          ),
          primaryLabel: l10n.save,
          onPrimary: () => Navigator.pop(ctx, selected),
          secondaryLabel: l10n.cancel,
          onSecondary: () => Navigator.pop(ctx),
        ),
      ),
    );

    if (result == null) return;
    onActivitiesChanged(result.map((a) => a.apiValue).toList());
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: l10n.deleteTrip,
        body: l10n.deleteTripConfirmation,
        primaryLabel: l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed == true) onDelete();
  }
}
