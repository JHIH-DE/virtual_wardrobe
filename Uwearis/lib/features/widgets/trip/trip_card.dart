import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/trip.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/app_popup_menu.dart';
import '../common/overlays/app_dialog.dart';
import '../common/overlays/text_input_dialog.dart';
import '../common/section_title.dart';

enum _TripCardAction { editName, delete }

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;

  const TripCard({
    super.key,
    required this.trip,
    required this.onTap,
    required this.onNameChanged,
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
            // Trimmed from the original 16/12 top/bottom now that
            // SectionTitle's default (bold16) renders shorter than it used
            // to — keeps the header block proportional to the title.
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: SectionTitle(trip.name)),
                    Transform.translate(
                      offset: const Offset(18, 0),
                      child: AppPopupMenu<_TripCardAction>(
                        onSelected: (action) => _handleAction(context, action),
                        items: [
                          AppPopupMenu.item(
                            value: _TripCardAction.editName,
                            icon: Image.asset(
                              'assets/images/edit.png',
                              width: 20,
                              height: 20,
                            ),
                            label: l10n.editTripName,
                          ),
                          AppPopupMenu.item(
                            value: _TripCardAction.delete,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: AppColors.icon,
                            ),
                            label: l10n.deleteTrip,
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  void _handleAction(BuildContext context, _TripCardAction action) {
    switch (action) {
      case _TripCardAction.editName:
        _editName(context);
      case _TripCardAction.delete:
        _confirmDelete(context);
    }
  }

  Future<void> _editName(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await showTextInputDialog(
      context,
      title: l10n.editTripName,
      hint: l10n.enterTripName,
      initialValue: trip.name,
    );
    if (result != null) onNameChanged(result);
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
