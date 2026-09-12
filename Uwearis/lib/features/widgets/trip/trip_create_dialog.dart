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

  /// Gates the "Create" button (see [AppDialog.onPrimary]'s disabled state)
  /// — greyed out until both a name and at least one location are in.
  bool get _canCreate =>
      _tripNameController.text.trim().isNotEmpty && _legsNotifier.value.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Neither controller/notifier rebuilds this State on its own —
    // _canCreate needs to be re-evaluated (and the Create button's
    // enabled/disabled look updated) whenever either changes.
    _tripNameController.addListener(_onFormChanged);
    _legsNotifier.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _tripNameController.removeListener(_onFormChanged);
    _legsNotifier.removeListener(_onFormChanged);
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
        onPrimary: _canCreate ? _submit : null,
        secondaryLabel: l10n.cancel,
        onSecondary: () => Navigator.pop(context),
      ),
    );
  }

  void _submit() {
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
