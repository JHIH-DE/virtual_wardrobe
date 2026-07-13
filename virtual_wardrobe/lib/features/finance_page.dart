import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/floating_nav_bar.dart';

class FinancePage extends StatelessWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.backgroundLight,
          appBar: AppToolBar(
            title: 'Finance',
            backgroundColor: AppColors.surface,
          ),
          body: const SafeArea(
            top: false,
            child: EmptyStatePlaceholder(
              message: 'Finance is coming soon',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
        ),
        const FloatingNavBar(current: AppTab.finance),
      ],
    );
  }
}
