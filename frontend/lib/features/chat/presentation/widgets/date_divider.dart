import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class DateDivider extends StatelessWidget {
  final String text;

  const DateDivider({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.darkCard, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.darkTextTertiary,
                fontSize: 11,
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.darkCard, thickness: 1),
          ),
        ],
      ),
    );
  }
}