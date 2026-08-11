import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class ReactionRow extends StatelessWidget {
  final List<String> reactions;

  const ReactionRow({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: reactions.map((r) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.darkBorder,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Text(
            r,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkTextPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}