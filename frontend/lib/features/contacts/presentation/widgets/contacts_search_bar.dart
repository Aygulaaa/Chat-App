import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class ContactsSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ContactsSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<ContactsSearchBar> createState() => _ContactsSearchBarState();
}

class _ContactsSearchBarState extends State<ContactsSearchBar> {
  FocusNode? _internalFocusNode;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return TapRegion(
      onTapOutside: (_) => _effectiveFocusNode.unfocus(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: widget.controller,
          focusNode: _effectiveFocusNode,
          cursorColor: AppColors.primary,
          style: TextStyle(color: context.textPrimary, fontSize: 15),
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.cardBg,
            hintText: 'Search users...',
            hintStyle: TextStyle(color: context.textTertiary, fontSize: 15),
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
      ),
    );
  }
}