import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/auth/local_auth_provider.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/core/widgets/secure_flow_widgets.dart';
import 'package:my_chat_app/features/auth/presentation/pages/auth_page.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';
import 'package:my_chat_app/features/settings/presentation/pages/app_lock_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/appearance_settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/change_password_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/privacy_settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';

const _user = UserEntity(id: 1, username: 'aygul', bio: 'Building things ✨');

// ── Fakes: no network, no Hive ───────────────────────────────────────────────

class FakeAuth extends AuthNotifier {
  FakeAuth({this.loggedIn = true, this.wrongPassword = false});
  final bool loggedIn;
  final bool wrongPassword;
  final calls = <String>[];

  @override
  AuthState build() => loggedIn
      ? const AuthState(user: _user, token: 't')
      : const AuthState();

  @override
  Future<void> login(String username, String password) async {
    calls.add('login:$username:$password');
    state = state.copyWith(
      error: ErrorHandler.getReadableErrorMessage(
        const ApiException(401, 'Invalid username or password'),
      ),
    );
  }

  @override
  Future<void> register(String username, String password) async =>
      calls.add('register:$username:$password');

  @override
  Future<bool> verifyPassword(String currentPassword) async {
    calls.add('verify');
    if (wrongPassword) throw Exception('Incorrect password');
    return true;
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async => calls.add('change:$currentPassword→$newPassword');

  @override
  Future<void> logout() async => calls.add('logout');
}

class FakeSettings extends SettingsNotifier {
  final updates = <Map<String, dynamic>>[];

  @override
  Future<UserSettings?> build() async => const UserSettings(userId: 1);

  @override
  Future<void> updateSettings(Map<String, dynamic> update) async {
    updates.add(update);
    final s = state.value!;
    state = AsyncData(
      s.copyWith(
        theme: update['theme'],
        hideLastSeen: update['hideLastSeen'],
        hideReadReceipts: update['hideReadReceipts'],
      ),
    );
  }
}

class FakeProfile extends UserProfile {
  @override
  Future<UserEntity?> build() async => _user;
}

class FakeBlocked extends BlockedContactsNotifier {
  @override
  Future<List<Contact>> build() async => const [];
}

class FakeLocalAuth extends LocalAuthNotifier {
  FakeLocalAuth({this.passcode});
  String? passcode;

  @override
  LocalAuthState build() =>
      LocalAuthState(isPasswordSet: passcode != null, isLocked: false);

  @override
  bool verifyLocalPassword(String password) => password == passcode;

  @override
  Future<void> setLocalPassword(String newPassword) async {
    passcode = newPassword;
    state = state.copyWith(isPasswordSet: true);
  }

  @override
  Future<void> removeLocalPassword() async {
    passcode = null;
    state = state.copyWith(isPasswordSet: false);
  }
}

// ── Harness ──────────────────────────────────────────────────────────────────

/// Real fonts make the optional screenshots readable. Purely cosmetic: if
/// the SDK's font cache isn't where we expect, tests run with the default
/// test font and every assertion still holds.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!File('$dir/Roboto-Regular.ttf').existsSync()) return;

  Future<ByteData> read(String f) async =>
      ByteData.view(File('$dir/$f').readAsBytesSync().buffer);
  await (FontLoader('Roboto')
        ..addFont(read('Roboto-Regular.ttf'))
        ..addFont(read('Roboto-Medium.ttf'))
        ..addFont(read('Roboto-Bold.ttf')))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(read('MaterialIcons-Regular.otf')))
      .load();
}

class Harness {
  Harness(this.auth, this.settings, this.localAuth, this.router);
  final FakeAuth auth;
  final FakeSettings settings;
  final FakeLocalAuth localAuth;
  final GoRouter router;
}

Future<Harness> pump(
  WidgetTester tester,
  Widget page, {
  ThemeData? theme,
  FakeAuth? auth,
  FakeLocalAuth? localAuth,
  bool pushed = true,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final a = auth ?? FakeAuth();
  final s = FakeSettings();
  final l = localAuth ?? FakeLocalAuth();
  final visited = <String>[];

  GoRoute stub(String path) => GoRoute(
    path: path,
    builder: (_, _) {
      visited.add(path);
      return Scaffold(body: Text('STUB $path'));
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => pushed ? const Scaffold(body: Text('ROOT')) : page),
      GoRoute(path: '/page', builder: (_, _) => page),
      for (final p in [
        '/settings/notifications', '/settings/privacy', '/settings/appearance',
        '/settings/change-password', '/settings/app-lock', '/sessions',
        '/blocked-contacts', '/edit-profile',
      ]) stub(p),
    ],
  );

  final base = theme ?? AppTheme.dark;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => a),
        settingsProvider.overrideWith(() => s),
        userProfileProvider.overrideWith(FakeProfile.new),
        blockedContactsProvider.overrideWith(FakeBlocked.new),
        localAuthProvider.overrideWith(() => l),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
          ),
        ),
      ),
    ),
  );
  if (pushed) router.push('/page');
  await tester.pumpAndSettle();
  return Harness(a, s, l, router);
}

Future<void> shot(WidgetTester tester, String name) async {
  if (Platform.environment['SHOTS'] == null) return;
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('${Platform.environment['SHOTS']}/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  group('login page', () {
    testWidgets('login: validates, submits trimmed values, shows server error inline', (tester) async {
      final h = await pump(tester, const AuthPage(), auth: FakeAuth(loggedIn: false), pushed: false);
      await shot(tester, 'login_dark');

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Repeat password'), findsNothing);

      // Button is inert until something is typed
      await tester.tap(find.text('Log In'));
      await tester.pump();
      expect(h.auth.calls, isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Username'), '  aygul ');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'hunter22');
      await tester.pump();
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle();

      expect(h.auth.calls, ['login:aygul:hunter22']);
      // The server's terse text is shown as guidance, not as-is
      expect(find.textContaining('Wrong username or password'), findsOneWidget);
      expect(find.textContaining('Create an account'), findsWidgets);
      await shot(tester, 'login_error_dark');

      // Typing again dismisses the server error
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'hunter23');
      await tester.pumpAndSettle();
      expect(find.textContaining('Wrong username or password'), findsNothing);
    });

    testWidgets('sign up: keeps username, enforces server rules before calling the API', (tester) async {
      final h = await pump(tester, const AuthPage(), auth: FakeAuth(loggedIn: false), pushed: false, theme: AppTheme.light);

      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ay');
      await tester.tap(find.text('Sign up'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('ay'), findsOneWidget, reason: 'username survives the tab switch');

      await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
      await tester.enterText(find.widgetWithText(TextField, 'Repeat password'), '124');
      await tester.pump();
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('At least 3 characters'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsOneWidget);
      expect(h.auth.calls, isEmpty, reason: 'invalid form never reaches the server');
      await shot(tester, 'signup_errors_light');

      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'aygul');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'correct horse 9!');
      await tester.enterText(find.widgetWithText(TextField, 'Repeat password'), 'correct horse 9!');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();
      expect(h.auth.calls, ['register:aygul:correct horse 9!']);
    });
  });

  group('settings', () {
    testWidgets('hub shows the profile and routes to each area', (tester) async {
      final h = await pump(tester, const SettingsScreen());
      await shot(tester, 'settings_hub_dark');

      expect(find.text('aygul'), findsOneWidget);
      expect(find.text('Building things ✨'), findsOneWidget);

      for (final entry in {
        'Notifications': '/settings/notifications',
        'Privacy and Security': '/settings/privacy',
        'Devices': '/sessions',
        'Appearance': '/settings/appearance',
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(find.text('STUB ${entry.value}'), findsOneWidget);
        h.router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('log out asks first', (tester) async {
      final h = await pump(tester, const SettingsScreen());
      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();
      expect(h.auth.calls, isEmpty);
      await tester.tap(find.text('Log Out').last); // the dialog's confirm button
      await tester.pumpAndSettle();
      expect(h.auth.calls, ['logout']);
    });

    testWidgets('privacy: toggles save, rows navigate', (tester) async {
      final h = await pump(tester, const PrivacySettingsScreen(), theme: AppTheme.light);
      await shot(tester, 'privacy_light');

      await tester.tap(find.text('Hide Last Seen')); // whole row is tappable
      await tester.pumpAndSettle();
      expect(h.settings.updates, [{'hideLastSeen': true}]);

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();
      expect(find.text('STUB /settings/change-password'), findsOneWidget);
    });

    testWidgets('appearance: picking a preview saves the theme', (tester) async {
      final h = await pump(tester, const AppearanceSettingsScreen());
      await shot(tester, 'appearance_dark');
      await tester.tap(find.text('Midnight')); // already selected → no-op
      // Another dark palette is a device choice: nothing goes to the server
      await tester.tap(find.text('Violet'));
      await tester.pumpAndSettle();
      expect(h.settings.updates, isEmpty);
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(h.settings.updates, [{'theme': 'light'}]);
    });
  });

  group('change password page', () {
    testWidgets('wrong current password is shown inline and blocks step 2', (tester) async {
      await pump(tester, const ChangePasswordScreen(), auth: FakeAuth(wrongPassword: true));
      await shot(tester, 'change_password_step1_dark');
      await tester.enterText(find.byType(TextField), 'nope');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining("That password isn't right"), findsOneWidget);
      expect(find.text('Create a new password'), findsNothing);
    });

    testWidgets('full flow: verify → validate → change → done; back steps backwards', (tester) async {
      final h = await pump(tester, const ChangePasswordScreen());
      await tester.enterText(find.byType(TextField), 'old-pass');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Create a new password'), findsOneWidget);

      // App-bar back on step 2 returns to step 1, it does not leave the flow
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your password'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      Future<void> fill(String a, String b) async {
        await tester.enterText(find.widgetWithText(TextField, 'New password'), a);
        await tester.enterText(find.widgetWithText(TextField, 'Repeat new password'), b);
        await tester.pump();
        await tester.tap(find.widgetWithText(FlowPrimaryButton, 'Change Password'));
        await tester.pumpAndSettle();
      }

      await fill('abc', 'abc');
      expect(find.text('Use at least 6 characters'), findsOneWidget);
      await fill('old-pass', 'old-pass');
      expect(find.textContaining('different from your current'), findsOneWidget);
      await fill('new-pass-1', 'new-pass-2');
      expect(find.text("Passwords don't match"), findsOneWidget);
      await shot(tester, 'change_password_step2_dark');
      expect(h.auth.calls.where((c) => c.startsWith('change')), isEmpty);

      await fill('new-pass-1', 'new-pass-1');
      expect(h.auth.calls.last, 'change:old-pass→new-pass-1');
      expect(find.text('Password changed'), findsOneWidget);
      await shot(tester, 'change_password_done_dark');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });
  });

  group('passcode lock page', () {
    testWidgets('turning it on needs matching passcodes of 4+', (tester) async {
      final h = await pump(tester, const AppLockScreen(), theme: AppTheme.light);
      await shot(tester, 'app_lock_create_light');
      await tester.enterText(find.widgetWithText(TextField, 'Passcode'), '12');
      await tester.enterText(find.widgetWithText(TextField, 'Repeat passcode'), '12');
      await tester.pump();
      await tester.tap(find.text('Turn Passcode On'));
      await tester.pumpAndSettle();
      expect(find.text('Use at least 4 characters'), findsOneWidget);
      expect(h.localAuth.passcode, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Passcode'), '4821');
      await tester.enterText(find.widgetWithText(TextField, 'Repeat passcode'), '4821');
      await tester.pump();
      await tester.tap(find.text('Turn Passcode On'));
      await tester.pumpAndSettle();
      expect(h.localAuth.passcode, '4821');
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('turning it off requires the current passcode', (tester) async {
      final h = await pump(tester, const AppLockScreen(), localAuth: FakeLocalAuth(passcode: '4821'));
      await shot(tester, 'app_lock_manage_dark');
      await tester.tap(find.text('Turn Passcode Off'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0000');
      await tester.pump();
      await tester.tap(find.text('Turn Off'));
      await tester.pumpAndSettle();
      expect(find.text('Wrong passcode'), findsOneWidget);
      expect(h.localAuth.passcode, '4821', reason: 'still protected');

      await tester.enterText(find.byType(TextField), '4821');
      await tester.pump();
      await tester.tap(find.text('Turn Off'));
      await tester.pumpAndSettle();
      expect(h.localAuth.passcode, isNull);
    });
  });

  test('password strength scoring', () {
    expect(PasswordStrengthMeter.score(''), 0);
    expect(PasswordStrengthMeter.score('abc'), 1);
    expect(PasswordStrengthMeter.score('abcdef'), 1);
    expect(PasswordStrengthMeter.score('abcdef12'), 2);
    expect(PasswordStrengthMeter.score('Correct horse 9!'), 4);
  });
}
