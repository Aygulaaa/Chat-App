import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;

  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onClose,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.glassBorder),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),

              Icon(
                Icons.search_rounded,
                color: context.textTertiary,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  cursorColor: AppColors.primary,
                  style: TextStyle(color: context.textPrimary, fontSize: 15),
                  onChanged: onChanged,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search chats...',
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                    ),
                  ),
                ),
              ),

              IconButton(
                icon: Icon(Icons.close_rounded, color: context.textSecondary),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}