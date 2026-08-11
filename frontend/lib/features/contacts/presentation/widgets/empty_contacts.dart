import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';

class EmptyContacts extends StatelessWidget {
  final String message;
  final String subtitle;
  final IconData icon;

  const EmptyContacts({
    super.key,
    this.message = 'No contacts yet',
    this.subtitle = 'Search for users to add them',
    this.icon = Icons.people_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.darkBorder, size: 72),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.darkTextTertiary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.darkBorder, fontSize: 13),
          ),
        ],
      ),
    );
  }
}