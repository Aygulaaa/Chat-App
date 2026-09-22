import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/core/widgets/secure_flow_widgets.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/widgets/auth_text_field.dart';

class AuthForm extends ConsumerStatefulWidget {
  const AuthForm({super.key});

  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  // Mirrors the server's rules so mistakes are caught before a round trip
  static const _minUsername = 3;
  static const _maxUsername = 30;
  static const _minPassword = 6;
  static const _maxPassword = 72;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLogin = true;

  /// Field errors stay hidden until the first submit attempt — nobody wants
  /// to be told "too short" while typing the second character.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_username, _password, _confirm]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // Typing is the user's answer to a server error — clear it
    if (ref.read(authProvider).error != null) {
      ref.read(authProvider.notifier).clearError();
    }
    setState(() {});
  }

  String? get _usernameError {
    final value = _username.text.trim();
    if (value.isEmpty) return 'Enter your username';
    if (_isLogin) return null;
    if (value.length < _minUsername) {
      return 'At least $_minUsername characters';
    }
    if (value.length > _maxUsername) return 'At most $_maxUsername characters';
    return null;
  }

  String? get _passwordError {
    final value = _password.text.trim();
    if (value.isEmpty) return 'Enter your password';
    if (_isLogin) return null;
    if (value.length < _minPassword) {
      return 'At least $_minPassword characters';
    }
    if (value.length > _maxPassword) return 'At most $_maxPassword characters';
    return null;
  }

  String? get _confirmError {
    if (_isLogin) return null;
    if (_confirm.text.trim() != _password.text.trim()) {
      return "Passwords don't match";
    }
    return null;
  }

  bool get _hasInput =>
      _username.text.trim().isNotEmpty &&
      _password.text.isNotEmpty &&
      (_isLogin || _confirm.text.isNotEmpty);

  void _submit() {
    if (ref.read(authProvider).isLoading) return;

    setState(() => _submitted = true);
    if (_usernameError != null ||
        _passwordError != null ||
        _confirmError != null) {
      HapticFeedback.heavyImpact();
      return;
    }

    FocusScope.of(context).unfocus();
    final notifier = ref.read(authProvider.notifier);
    final username = _username.text.trim();
    final password = _password.text.trim();
    _isLogin
        ? notifier.login(username, password)
        : notifier.register(username, password);
  }

  void _setMode(bool login) {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _isLogin = login;
      _submitted = false;
      // Keep the username (people often hit the wrong tab first); passwords
      // are re-entered.
      _password.clear();
      _confirm.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final loading = state.isLoading;
    final serverError = state.error == null
        ? null
        : ErrorHandler.getReadableErrorMessage(state.error);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.authBg,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: context.authBgGradient),
          child: Stack(
            children: [
              const Positioned(top: -120, right: -90, child: _Glow(size: 320)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      // Vertically centered when there's room, scrollable
                      // when the keyboard is up
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildContent(context, loading, serverError),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool loading,
    String? serverError,
  ) {
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Center(child: _BrandMark()),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Column(
              key: ValueKey(_isLogin),
              children: [
                Text(
                  _isLogin ? 'Welcome back' : 'Create your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? 'Log in to pick up your conversations.'
                      : 'Pick a username and start chatting in seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          AuthModeSwitch(
            isLogin: _isLogin,
            enabled: !loading,
            onChanged: _setMode,
          ),
          const SizedBox(height: 22),
          AuthTextField(
            controller: _username,
            hint: 'Username',
            icon: Icons.alternate_email_rounded,
            enabled: !loading,
            errorText: _submitted ? _usernameError : null,
            autofillHints: [
              _isLogin ? AutofillHints.username : AutofillHints.newUsername,
            ],
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _password,
            focusNode: _passwordFocus,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            enabled: !loading,
            errorText: _submitted ? _passwordError : null,
            textInputAction: _isLogin
                ? TextInputAction.done
                : TextInputAction.next,
            autofillHints: [
              _isLogin ? AutofillHints.password : AutofillHints.newPassword,
            ],
            onSubmitted: (_) =>
                _isLogin ? _submit() : _confirmFocus.requestFocus(),
          ),
          // Sign-up extras slide open instead of popping in
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isLogin
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: PasswordStrengthMeter(
                          password: _password.text.trim(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AuthTextField(
                        controller: _confirm,
                        focusNode: _confirmFocus,
                        hint: 'Repeat password',
                        icon: Icons.verified_user_outlined,
                        isPassword: true,
                        enabled: !loading,
                        errorText: _submitted ? _confirmError : null,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
          ),
          // Server errors appear right above the button they relate to
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: serverError == null || serverError.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _ErrorBanner(message: serverError),
                  ),
          ),
          const SizedBox(height: 22),
          FlowPrimaryButton(
            label: _isLogin ? 'Log In' : 'Create Account',
            loading: loading,
            onPressed: _hasInput ? _submit : null,
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: loading ? null : () => _setMode(!_isLogin),
              child: Text.rich(
                TextSpan(
                  text: _isLogin ? 'New here? ' : 'Already have an account? ',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                      text: _isLogin ? 'Create an account' : 'Log in',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}

/// Soft brand-colored light in a corner. A plain radial gradient — the old
/// full-screen BackdropFilter blur cost a lot of GPU for the same effect.
class _Glow extends StatelessWidget {
  final double size;

  const _Glow({required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primary.withValues(
                alpha: context.isLight ? 0.22 : 0.20,
              ),
              AppColors.accent.withValues(alpha: 0.08),
              AppColors.accent.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFFF5A52);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
