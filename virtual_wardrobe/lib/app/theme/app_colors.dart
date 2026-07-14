import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  // Fashion Editorial base
  static const Color defaultBackground = Color(0xFFF5F4F0);
  static const Color defaultToolBar = Color(0xFFFFFFFF);
  static const Color defaultButton = Color(0xFF222325);
  static const Color defaultButtonText = Color(0xFFFFFFFF);
  static const Color defaultCard = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF); // 卡片白
  static const Color border = Color(0xFFE6E6E6); // 細邊框灰
  static const Color textPrimary = Color(0xFF222325); // 近黑
  static const Color textPrimaryInv = Color(0xFFFFFFFF); // 白
  static const Color textSecondary = Color(0xFF6F6F6F); // 次要文字灰
  static const Color dividerStrong = Color(0xFF18191B);
  static const Color dividerSubtle = Color(0xFFE6E6E6);
  static const Color defaultMask = Color(0x5C181E2B); // #181E2B 36%

  // Social Colors
  static const Color facebook = Color(0xFF1877F2); // Facebook Blue
  static const Color google = Color(0xFF4285F4); // Google Blue (optional)

  // Accent (Editorial 常用：Deep Navy)
  static const Color primary = Color(0xFF1C2A3A);
  static const Color textFacebookIconBackground = Color(0xFF6F6F6F);

  // 你原本用到的命名：保留，讓現有 code 不用大改
  static const Color card = surface;
  static const Color cardContent = textPrimary;

  static const Color textBoxBorder = Color(0xFFA0A4AB);

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF00BFA5);

  static const Color statusClicked = Color(0x5CC6C0AB); // #C6C0AB 36%

  // Solid black accent used for primary buttons / selected states
  static const Color nearBlack = Color(0xFF1A1A1A);

  // Empty-state upload placeholder (Body Profile photo picker)
  static const Color placeholderBorder = Color(0xFFBBBBBB);
  static const Color placeholderBackground = Color(0xFFEEEEEE);

  // AppCard drop shadow (two-tone hard shadow)
  static const Color cardShadowTop = Color(0xFFDDDDDD);
  static const Color cardShadowBottom = Color(0xFFCCCCCC);

  static const Color hintText = Color(0xFF9E9E9E);
  static const Color placeholderIcon = Color(0xFFBDBDBD);
  static const Color avatarPlaceholderBackground = Color(0xFFE0E0E0);
  static const Color dropdownBorder = Color(0xFF2B3A8C);
}
