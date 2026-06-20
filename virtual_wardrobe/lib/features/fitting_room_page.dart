import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'widgets/page_app_bar.dart';
import 'closet_looks_tab.dart';
import 'closet_outfit_tab.dart';

class FittingRoomPage extends StatefulWidget {
  const FittingRoomPage({super.key});

  @override
  State<FittingRoomPage> createState() => _FittingRoomPageState();
}

class _FittingRoomPageState extends State<FittingRoomPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: PageAppBar(
          title: 'Fitting Room',
          backgroundColor: AppColors.surface,
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Try on', icon: Icon(Icons.checkroom)),
              Tab(text: 'Looks', icon: Icon(Icons.style)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ClosetOutfitTab(),
            ClosetLooksTab(),
          ],
        ),
      ),
    );
  }
}