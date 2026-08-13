import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class ContactsSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ContactsSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<ContactsSearchBar> createState() => _ContactsSearchBarState();
}

class _ContactsSearchBarState extends State<ContactsSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: widget.controller,
        cursorColor: AppColors.primary,
        style: TextStyle(
          color: context.textPrimary,
          fontSize: 15,
        ),
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: context.cardBg,
          hintText: 'Search users...',
          hintStyle: TextStyle(
            color: context.textTertiary,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: context.textTertiary,
            size: 20,
          ),
          suffixIcon: hasText
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.textTertiary,
                    size: 20,
                  ),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.glassBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.glassBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 4,
          ),
        ),
      ),
    );
  }
}