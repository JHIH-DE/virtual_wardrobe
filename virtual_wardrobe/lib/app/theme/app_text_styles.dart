import 'package:flutter/material.dart';

class AppTextStyle {
  static const TextStyle bold20 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle bold16 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.375, // line-height: 22px / font-size: 16px
    letterSpacing: 0,
  );

  static const TextStyle bold14 = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  // Dialog title: Bold 20px, line-height 100%
  static const TextStyle dialogTitle = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.0,
    letterSpacing: 0,
  );

  // Dialog body: Medium 16px, line-height 22px
  static const TextStyle dialogBody = TextStyle(
    fontFamily: 'text/EN',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.375, // 22px / 16px
    letterSpacing: 0,
  );
}
