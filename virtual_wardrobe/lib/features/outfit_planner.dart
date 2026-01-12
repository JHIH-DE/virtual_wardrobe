import 'package:flutter/material.dart';

enum PlannerMode { daily, trip }

class OutfitPlannerPage extends StatefulWidget {
  const OutfitPlannerPage({super.key});

  @override
  State<OutfitPlannerPage> createState() => _OutfitPlannerPageState();
}

class _OutfitPlannerPageState extends State<OutfitPlannerPage> {
  PlannerMode _mode = PlannerMode.daily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Outfit Planner')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _modeSwitcher(),
          const SizedBox(height: 14),

          if (_mode == PlannerMode.daily) ...[
            _buildDailyPlanner(),
          ] else ...[
            _buildTripPlanner(),
          ],
        ],
      ),
    );
  }

  Widget _modeSwitcher() {
    return SegmentedButton<PlannerMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: PlannerMode.daily,
          icon: Icon(Icons.wb_sunny_outlined),
          label: Text('Daily'),
        ),
        ButtonSegment(
          value: PlannerMode.trip,
          icon: Icon(Icons.luggage_outlined),
          label: Text('Trip'),
        ),
      ],
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  Widget _buildDailyPlanner() {
    return const Text('TODO: Daily outfit content here');
  }

  Widget _buildTripPlanner() {
    return const Text('TODO: Trip planner content here');
  }
}