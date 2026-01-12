import 'package:flutter/material.dart';
import 'closet_garments_tab.dart';
import 'closet_outfit_tab.dart';
import 'closet_looks_tab.dart';
import '../app/theme/app_colors.dart';

class MyClosetPage extends StatefulWidget {
  const MyClosetPage({super.key});

  @override
  State<MyClosetPage> createState() => _MyClosetPageState();
}

class _MyClosetPageState extends State<MyClosetPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Closet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: const IconThemeData(
            color: AppColors.textPrimary,
          ),
          bottom: TabBar(
            indicatorColor: AppColors.primary,
            indicatorWeight: 2.5,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Garments', icon: Icon(Icons.checkroom)),
              Tab(text: 'Outfit', icon: Icon(Icons.style)),
              Tab(text: 'Looks', icon: Icon(Icons.collections_bookmark)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ClosetGarmentsTab(),
            ClosetOutfitTab(),
            ClosetLooksTab(),
          ],
        ),
      ),
    );
  }
}