import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'widgets/page_app_bar.dart';
import 'daily_planner_tab.dart';
import 'trip_planner_tab.dart';

class OutfitPlannerPage extends StatefulWidget {
  const OutfitPlannerPage({super.key});

  @override
  State<OutfitPlannerPage> createState() => _OutfitPlannerPageState();
}

class _OutfitPlannerPageState extends State<OutfitPlannerPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PageAppBar(
          title: 'Outfit Planner',
          backgroundColor: AppColors.surface,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Daily', icon: Icon(Icons.wb_sunny_outlined)),
              Tab(text: 'Trip', icon: Icon(Icons.luggage_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            DailyPlannerTab(),
            TripPlannerTab(),
          ],
        ),
      ),
    );
  }
}