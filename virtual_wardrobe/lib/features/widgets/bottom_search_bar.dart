import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';

class BottomSearchBar extends StatelessWidget {
  const BottomSearchBar({
    super.key,
    required this.hint,
    this.onTap,
  });

  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(22, 22, 22, 8 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
        ),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.only(left: 24, right: 6),
          child: Row(
              children: [
                Expanded(
                  child: Text(
                    hint,
                    style: AppTextStyle.bold16.copyWith(
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Image.asset('assets/images/search.png', height: 28),
                    onPressed: onTap,
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}
