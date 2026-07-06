import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'add_garment_page.dart';
import 'body_profile_page.dart';
import 'manual_try_on_page.dart';
import 'trip_planner_page.dart';
import 'widgets/app_card.dart';
import 'widgets/page_app_bar.dart';

class CreatePage extends StatelessWidget {
  const CreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: PageAppBar(
        title: 'Create',
        backgroundColor: AppColors.defaultToolBar,
        actions: [
          IconButton(
            icon: Container(
              child: Image.asset(
                'assets/images/figure_setting.png',
                height: 40,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BodyProfilePage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            _buildCard(
              context,
              label: 'Add Clothing',
              iconPath: 'assets/images/add.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddGarmentPage()),
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Manual Try-on',
              iconPath: 'assets/images/manul.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManualTryOnPage(
                    onBack: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Daily Planner',
              iconPath: 'assets/images/daily_planner.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripPlannerPage()),
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Trip Planner',
              iconPath: 'assets/images/trip_planner.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripPlannerPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String label,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return AppVerticalCard(
      label: label,
      iconPath: iconPath,
      isSelected: false,
      onTap: onTap,
      height: 140,
    );
  }
}
