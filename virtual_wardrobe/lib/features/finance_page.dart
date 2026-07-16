import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  AppToolBar _buildAppBar() {
    return AppToolBar(title: 'Finance', showBackButton: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: const EmptyStatePlaceholder(
        message: 'Finance is coming soon',
        icon: Icons.account_balance_wallet_outlined,
      ),
    );
  }
}
