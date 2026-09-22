import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

class AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool enabled;
  final String? errorText;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.isPassword = false,
    this.enabled = true,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    const errorColor = Color(0xFFFF5A52);

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscured,
      autocorrect: false,
      enableSuggestions: !widget.isPassword,
      textCapitalization: TextCapitalization.none,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      cursorColor: AppColors.primary,
      style: TextStyle(
        color: context.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(
          color: context.textTertiary,
          fontSize: 15.5,
          fontWeight: FontWeight.w400,
        ),
        errorText: widget.errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(color: errorColor, fontSize: 12.5),
        filled: true,
        fillColor: context.inputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 17),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 10),
          child: Icon(widget.icon, size: 21, color: context.textTertiary),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscured ? 'Show password' : 'Hide password',
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: context.textTertiary,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : null,
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.primary, 1.6),
        errorBorder: border(errorColor),
        focusedErrorBorder: border(errorColor, 1.6),
      ),
    );
  }
}

/// "Log in | Sign up" switch with a sliding highlight.
class AuthModeSwitch extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  const AuthModeSwitch({
    super.key,
    required this.isLogin,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget label(String text, bool selected, bool value) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled && !selected ? () => onChanged(value) : null,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              // merge, don't replace: a bare TextStyle here would drop the
              // inherited font family
              style: DefaultTextStyle.of(context).style.merge(
                TextStyle(
                  fontSize: 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? context.textPrimary : context.textTertiary,
                ),
              ),
              child: Text(text),
            ),
          ),
        ),
      ),
    );

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.inputFill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: isLogin ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.isLight
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: context.isLight ? 0.08 : 0.25,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              label('Log in', isLogin, true),
              label('Sign up', !isLogin, false),
            ],
          ),
        ],
      ),
    );
  }
}
