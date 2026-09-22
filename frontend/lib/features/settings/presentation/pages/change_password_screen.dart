import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/core/widgets/secure_flow_widgets.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

/// Full-page password change:
///   1. prove you know the current password (checked with the server)
///   2. choose + confirm the new one
///   3. confirmation
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  static const _minLength = 6;
  static const _maxLength = 72; // bcrypt ignores everything past 72 bytes

  final _pages = PageController();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  int _step = 0;
  bool _loading = false;
  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void dispose() {
    _pages.dispose();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _verifyCurrent() async {
    if (_loading) return;
    if (_current.text.isEmpty) {
      setState(() => _currentError = 'Enter your current password');
      return;
    }

    setState(() {
      _loading = true;
      _currentError = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyPassword(_current.text);
      if (mounted) _goTo(1);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _currentError = ErrorHandler.getReadableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validateNew() {
    final next = _next.text;
    String? nextError;
    String? confirmError;

    if (next.length < _minLength) {
      nextError = 'Use at least $_minLength characters';
    } else if (next.length > _maxLength) {
      nextError = 'Use at most $_maxLength characters';
    } else if (next == _current.text) {
      nextError = 'Choose a password different from your current one';
    }
    if (nextError == null && _confirm.text != next) {
      confirmError = "Passwords don't match";
    }

    setState(() {
      _nextError = nextError;
      _confirmError = confirmError;
    });
    return nextError == null && confirmError == null;
  }

  Future<void> _submit() async {
    if (_loading || !_validateNew()) return;

    setState(() => _loading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      // Don't keep secrets in memory longer than needed
      _current.clear();
      _next.clear();
      _confirm.clear();
      _goTo(2);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _nextError = ErrorHandler.getReadableErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back on step 2 returns to step 1 instead of leaving the flow
      canPop: _step != 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == 1) _goTo(0);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SettingsScaffold(
          title: _step == 2 ? '' : 'Change Password',
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_step < 2) _StepIndicator(step: _step),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _page(
                        header: const FlowHeader(
                          icon: Icons.lock_outline_rounded,
                          color: SettingsColors.blue,
                          title: 'Enter your password',
                          message:
                              "First, confirm it's you by entering your "
                              'current password.',
                        ),
                        fields: [
                          FlowPasswordField(
                            controller: _current,
                            hint: 'Current password',
                            autofocus: true,
                            enabled: !_loading,
                            errorText: _currentError,
                            autofillHints: const [AutofillHints.password],
                            onChanged: (_) {
                              if (_currentError != null) {
                                setState(() => _currentError = null);
                              } else {
                                setState(() {});
                              }
                            },
                            onSubmitted: (_) => _verifyCurrent(),
                          ),
                        ],
                        button: FlowPrimaryButton(
                          label: 'Continue',
                          loading: _loading,
                          onPressed: _current.text.isEmpty
                              ? null
                              : _verifyCurrent,
                        ),
                      ),
                      _page(
                        header: const FlowHeader(
                          icon: Icons.key_rounded,
                          color: SettingsColors.green,
                          title: 'Create a new password',
                          message:
                              'Longer is stronger. A short phrase you can '
                              'remember beats a hard-to-type jumble.',
                        ),
                        fields: [
                          FlowPasswordField(
                            controller: _next,
                            hint: 'New password',
                            enabled: !_loading,
                            errorText: _nextError,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) => setState(() => _nextError = null),
                          ),
                          const SizedBox(height: 10),
                          PasswordStrengthMeter(password: _next.text),
                          const SizedBox(height: 16),
                          FlowPasswordField(
                            controller: _confirm,
                            hint: 'Repeat new password',
                            enabled: !_loading,
                            errorText: _confirmError,
                            autofillHints: const [AutofillHints.newPassword],
                            onChanged: (_) =>
                                setState(() => _confirmError = null),
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                        button: FlowPrimaryButton(
                          label: 'Change Password',
                          loading: _loading,
                          onPressed: _next.text.isEmpty || _confirm.text.isEmpty
                              ? null
                              : _submit,
                        ),
                      ),
                      _page(
                        header: const FlowHeader(
                          icon: Icons.check_rounded,
                          color: SettingsColors.green,
                          title: 'Password changed',
                          message:
                              'For your security, every other device has been '
                              'signed out. This one stays logged in.',
                        ),
                        fields: const [],
                        button: FlowPrimaryButton(
                          label: 'Done',
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header and fields scroll (so the keyboard never hides them); the button
  /// stays pinned at the bottom, above the keyboard.
  Widget _page({
    required Widget header,
    required List<Widget> fields,
    required Widget button,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, const SizedBox(height: 30), ...fields],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: button,
        ),
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 2; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i <= step
                    ? context.primaryColor
                    : context.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
