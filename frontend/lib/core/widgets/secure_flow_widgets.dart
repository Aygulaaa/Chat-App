import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// Pieces shared by the full-page security flows (Change Password, Passcode
/// Lock): a hero icon + headline, a password field and a primary button.

class FlowHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  /// Defaults to the palette's primary color.
  final Color? color;

  const FlowHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.primaryColor;

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: context.isLight ? 0.14 : 0.18),
          ),
          child: Icon(icon, size: 42, color: color),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class FlowPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? errorText;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const FlowPasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.errorText,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<FlowPasswordField> createState() => _FlowPasswordFieldState();
}

class _FlowPasswordFieldState extends State<FlowPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      obscureText: _obscured,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      cursorColor: AppColors.primary,
      style: TextStyle(color: context.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: context.textTertiary, fontSize: 15.5),
        errorText: widget.errorText,
        errorMaxLines: 2,
        filled: true,
        fillColor: context.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show' : 'Hide',
          icon: Icon(
            _obscured
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: context.textTertiary,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
        border: border(Colors.transparent),
        enabledBorder: border(Colors.transparent),
        disabledBorder: border(Colors.transparent),
        focusedBorder: border(AppColors.primary, 1.5),
        errorBorder: border(const Color(0xFFFF5A52)),
        focusedErrorBorder: border(const Color(0xFFFF5A52), 1.5),
      ),
    );
  }
}

class FlowPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;

  const FlowPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled || loading ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: destructive ? null : AppColors.primaryGradient,
            color: destructive ? const Color(0xFFFF5A52) : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four-segment strength meter with a one-word verdict.
class PasswordStrengthMeter extends StatelessWidget {
  final String password;

  const PasswordStrengthMeter({super.key, required this.password});

  /// 0 (empty) … 4 (strong). Length matters most; variety adds to it.
  static int score(String p) {
    if (p.isEmpty) return 0;
    if (p.length < 6) return 1;
    var points = 1;
    if (p.length >= 10) points++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) points++;
    if (RegExp(r'\d').hasMatch(p)) points++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) points++;
    return points.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final value = score(password);
    const labels = ['', 'Too short', 'Weak', 'Good', 'Strong'];
    const colors = [
      Colors.transparent,
      Color(0xFFFF5A52),
      Color(0xFFF59331),
      Color(0xFFE5C03A),
      Color(0xFF3DBD63),
    ];
    // "Too short" only applies under 6 chars; a 6+ char score of 1 is "Weak"
    final label = value == 1 && password.length >= 6 ? 'Weak' : labels[value];

    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i <= value
                    ? colors[value]
                    : context.textTertiary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 5),
        ],
        SizedBox(
          width: 66,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: value == 0 ? context.textTertiary : colors[value],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
