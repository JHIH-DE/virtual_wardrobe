import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Fashion Editorial base
  static const Color background = Color(0xFFF2F0ED);     // 淡紙色底
  static const Color surface = Color(0xFFFFFFFF);        // 卡片白
  static const Color border = Color(0xFFE6E6E6);         // 細邊框灰
  static const Color textPrimary = Color(0xFF111111);    // 近黑
  static const Color textSecondary = Color(0xFF6F6F6F);  // 次要文字灰
  // Accent (Editorial 常用：Deep Navy)
  static const Color primary = Color(0xFF1C2A3A);

  // 你原本用到的命名：保留，讓現有 code 不用大改
  static const Color card = surface;
  static const Color cardContent = textPrimary;
}