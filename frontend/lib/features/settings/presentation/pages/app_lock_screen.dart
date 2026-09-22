import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/utils/snackbar_utils.dart';
import 'package:my_chat_app/core/widgets/secure_flow_widgets.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_scaffold.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_section.dart';
import 'package:my_chat_app/features/settings/presentation/widgets/settings_tile.dart';

enum _Mode { manage, verify, create }

enum _After { change, turnOff }

/// Passcode Lock: turn it on, change it, or turn it off. Changing or removing
/// an existing passcode first requires entering it — previously anyone holding
/// the unlocked phone could switch the lock off with one tap.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  static const _minLength = 4;

  final _existing = TextEditingController();
  final _passcode = TextEditingController();
  final _confirm = TextEditingController();

  late _Mode _mode;
  _After _after = _After.change;
  String? _existingError;
  String? _passcodeError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(localAuthProvider).isPasswordSet
        ? _Mode.manage
        : _Mode.create;
  }

  @override
  void dispose() {
    _existing.dispose();
    _passcode.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startVerify(_After after) {
    _existing.clear();
    setState(() {
      _after = after;
      _existingError = null;
      _mode = _Mode.verify;
    });
  }

  Future<void> _submitVerify() async {
    final notifier = ref.read(localAuthProvider.notifier);
    if (!notifier.verifyLocalPassword(_existing.text)) {
      HapticFeedback.heavyImpact();
      setState(() => _existingError = 'Wrong passcode');
      return;
    }

    if (_after == _After.turnOff) {
      await notifier.removeLocalPassword();
      if (!mounted) return;
      SnackBarUtils.showSnack(context, 'Passcode Lock turned off');
      context.pop();
    } else {
      _passcode.clear();
      _confirm.clear();
      setState(() => _mode = _Mode.create);
    }
  }

  Future<void> _submitCreate() async {
    final code = _passcode.text;
    String? passcodeError;
    String? confirmError;
    if (code.length < _minLength) {
      passcodeError = 'Use at least $_minLength characters';
    } else if (_confirm.text != code) {
      confirmError = "Passcodes don't match";
    }
    setState(() {
      _passcodeError = passcodeError;
      _confirmError = confirmError;
    });
    if (passcodeError != null || confirmError != null) return;

    await ref.read(localAuthProvider.notifier).setLocalPassword(code);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    SnackBarUtils.showSnack(context, 'Passcode Lock is on');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSet = ref.watch(localAuthProvider.select((s) => s.isPasswordSet));

    return PopScope(
      // Back from "enter current passcode" returns to the menu, not out
      canPop: !(_mode == _Mode.verify || (_mode == _Mode.create && isSet)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _mode = _Mode.manage);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SettingsScaffold(
          title: 'Passcode Lock',
          body: SafeArea(
            top: false,
            child: switch (_mode) {
              _Mode.manage => _buildManage(),
              _Mode.verify => _buildVerify(),
              _Mode.create => _buildCreate(isChange: isSet),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildManage() {
    return ListView(
      padding: const EdgeInsets.only(top: 20, bottom: 32),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: FlowHeader(
            icon: Icons.lock_rounded,
            color: SettingsColors.green,
            title: 'Passcode Lock is on',
            message:
                'The app asks for your passcode every time it is opened on '
                'this device.',
          ),
        ),
        SettingsSection(
          dividerIndent: 16,
          footer:
              'Forgot it? On the lock screen you can reset the passcode with '
              'your account password.',
          children: [
            SettingsTile(
              title: 'Change Passcode',
              onTap: () => _startVerify(_After.change),
            ),
            SettingsTile(
              title: 'Turn Passcode Off',
              destructive: true,
              onTap: () => _startVerify(_After.turnOff),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVerify() {
    return _FlowPage(
      header: const FlowHeader(
        icon: Icons.lock_outline_rounded,
        color: SettingsColors.blue,
        title: 'Enter your passcode',
        message: 'Confirm your current passcode to continue.',
      ),
      fields: [
        FlowPasswordField(
          controller: _existing,
          hint: 'Current passcode',
          autofocus: true,
          errorText: _existingError,
          onChanged: (_) => setState(() => _existingError = null),
          onSubmitted: (_) => _submitVerify(),
        ),
      ],
      button: FlowPrimaryButton(
        label: _after == _After.turnOff ? 'Turn Off' : 'Continue',
        destructive: _after == _After.turnOff,
        onPressed: _existing.text.isEmpty ? null : _submitVerify,
      ),
    );
  }

  Widget _buildCreate({required bool isChange}) {
    return _FlowPage(
      header: FlowHeader(
        icon: Icons.pin_rounded,
        color: SettingsColors.green,
        title: isChange ? 'Choose a new passcode' : 'Set a passcode',
        message:
            "You'll enter it each time you open the app. It is stored only "
            'on this device and is separate from your account password.',
      ),
      fields: [
        FlowPasswordField(
          controller: _passcode,
          hint: 'Passcode',
          autofocus: true,
          errorText: _passcodeError,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _passcodeError = null),
        ),
        const SizedBox(height: 14),
        FlowPasswordField(
          controller: _confirm,
          hint: 'Repeat passcode',
          errorText: _confirmError,
          onChanged: (_) => setState(() => _confirmError = null),
          onSubmitted: (_) => _submitCreate(),
        ),
      ],
      button: FlowPrimaryButton(
        label: isChange ? 'Save Passcode' : 'Turn Passcode On',
        onPressed: _passcode.text.isEmpty || _confirm.text.isEmpty
            ? null
            : _submitCreate,
      ),
    );
  }
}

class _FlowPage extends StatelessWidget {
  final Widget header;
  final List<Widget> fields;
  final Widget button;

  const _FlowPage({
    required this.header,
    required this.fields,
    required this.button,
  });

  @override
  Widget build(BuildContext context) {
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
