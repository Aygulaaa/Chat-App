import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/user_status_state.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/group/create_group_modal.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';
import 'package:my_chat_app/features/profile/presentation/pages/edit_profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:my_chat_app/features/profile/presentation/providers/user_provider.dart';
import 'package:my_chat_app/features/settings/domain/entities/user_settings.dart';
import 'package:my_chat_app/features/settings/presentation/providers/settings_provider.dart';

final _me = UserEntity(id: 1, username: 'aygul', bio: 'Building things', birthDate: DateTime(1999, 4, 12));
const _other = UserEntity(id: 2, username: 'timur', bio: 'Coffee, code, repeat');

class FakeAuth extends AuthNotifier {
  final calls = <String>[];
  @override
  AuthState build() => AuthState(user: _me, token: 't');
  @override
  Future<void> logout() async => calls.add('logout');
}

class FakeProfile extends UserProfile {
  final saved = <Map<String, dynamic>>[];
  Object? failWith;
  @override
  Future<UserEntity?> build() async => _me;
  @override
  Future<void> updateInfo(Map<String, dynamic> data) async {
    if (failWith != null) throw failWith!;
    saved.add(data);
  }
}

class FakeSettings extends SettingsNotifier {
  @override
  Future<UserSettings?> build() async => const UserSettings(userId: 1);
}

class FakeContacts extends ContactsNotifier {
  FakeContacts(this.initial);
  final List<Contact> initial;
  final calls = <String>[];
  @override
  Future<List<Contact>> build() async => initial;
  @override
  Future<void> addContact(int id) async => calls.add('add:$id');
  @override
  Future<void> removeContact(int id) async => calls.add('remove:$id');
  @override
  Future<void> blockUser(int id) async => calls.add('block:$id');
}

class FakeBlocked extends BlockedContactsNotifier {
  @override
  Future<List<Contact>> build() async => const [];
}

class FakeStatus extends UserStatusNotifier {
  @override
  UserStatusState build() => const UserStatusState(onlineUsers: {2: true});
}

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  if (!File('$dir/Roboto-Regular.ttf').existsSync()) return;
  Future<ByteData> read(String f) async => ByteData.view(File('$dir/$f').readAsBytesSync().buffer);
  await (FontLoader('Roboto')..addFont(read('Roboto-Regular.ttf'))..addFont(read('Roboto-Medium.ttf'))..addFont(read('Roboto-Bold.ttf'))).load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

class H {
  H(this.auth, this.profile, this.contacts, this.router);
  final FakeAuth auth;
  final FakeProfile profile;
  final FakeContacts contacts;
  final GoRouter router;
}

Future<H> pump(WidgetTester tester, Widget page, {ThemeData? theme, List<Contact> contacts = const [], bool pushed = true}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final auth = FakeAuth(), profile = FakeProfile(), c = FakeContacts(contacts);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => pushed ? const Scaffold(body: Text('ROOT')) : page),
    GoRoute(path: '/page', builder: (_, _) => page),
    for (final p in ['/edit-profile', '/settings']) GoRoute(path: p, builder: (_, _) => Scaffold(body: Text('STUB $p'))),
  ]);
  final base = theme ?? AppTheme.dark;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(() => auth),
      userProfileProvider.overrideWith(() => profile),
      settingsProvider.overrideWith(FakeSettings.new),
      contactsProvider.overrideWith(() => c),
      blockedContactsProvider.overrideWith(FakeBlocked.new),
      userStatusProvider.overrideWith(FakeStatus.new),
      userByIdProvider(2).overrideWith((ref) async => _other),
    ],
    child: ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto')),
      ),
    ),
  ));
  if (pushed) router.push('/page');
  await tester.pumpAndSettle();
  return H(auth, profile, c, router);
}

Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOTS'];
  if (dir == null) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$dir/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('my profile: info, entry points, confirmed logout', (tester) async {
    final h = await pump(tester, const ProfileScreen(), pushed: false);
    await shot(tester, 'profile_me_dark');
    expect(find.text('aygul'), findsOneWidget);
    expect(find.text('@aygul'), findsOneWidget);
    // My own page is just the photo, the handle and the entry points
    expect(find.text('April 12, 1999'), findsNothing);
    expect(find.text('Building things'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('STUB /settings'), findsOneWidget);
    h.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();
    expect(h.auth.calls, isEmpty, reason: 'asks first');
    await tester.tap(find.text('Log Out').last);
    await tester.pumpAndSettle();
    expect(h.auth.calls, ['logout']);
  });

  testWidgets('every palette draws the profile in its own colors', (tester) async {
    addTearDown(() => AppColors.active = const DarkColors());
    for (final palette in AppColors.palettes) {
      AppColors.active = palette;
      await pump(tester, const ProfileScreen(), theme: AppTheme.of(palette), pushed: false);
      await shot(tester, 'profile_me_${palette.id}');
      final context = tester.element(find.text('@aygul'));
      expect(Theme.of(context).extension<AppPalette>()!.scheme.id, palette.id);
      expect(AppColors.of(context).primary, palette.primary);
    }
  });

  testWidgets("other user's profile: live status, quick actions, confirmed block", (tester) async {
    final h = await pump(tester, const ProfileScreen(user: _other), theme: AppTheme.light);
    await shot(tester, 'profile_other_light');
    expect(find.text('online'), findsOneWidget);
    expect(find.text('Coffee, code, repeat'), findsOneWidget);

    // Scrolling folds the photo into the pinned bar; the name stays on screen
    for (final (dy, name) in [(-170.0, 'profile_other_mid_light'), (-400.0, 'profile_other_collapsed_light')]) {
      await tester.drag(find.byType(CustomScrollView), Offset(0, dy));
      await tester.pumpAndSettle();
      await shot(tester, name);
    }
    expect(find.text('timur'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 900));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(h.contacts.calls, ['add:2']);

    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(h.contacts.calls, ['add:2'], reason: 'block asks first');
    await tester.tap(find.text('Block').last);
    await tester.pumpAndSettle();
    expect(h.contacts.calls, ['add:2', 'block:2']);
  });

  testWidgets('edit profile: Done only when changed, validates, saves, guards unsaved edits', (tester) async {
    final h = await pump(tester, EditProfileScreen(user: _me));
    await shot(tester, 'edit_profile_dark');

    TextButton done() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Done'));
    expect(done().onPressed, isNull, reason: 'nothing changed yet');

    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ay');
    await tester.pump();
    expect(done().onPressed, isNotNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Use between 3 and 30 characters'), findsOneWidget);
    expect(h.profile.saved, isEmpty);

    // Leaving with edits asks before throwing them away
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    // Server rejection lands under the field it is about
    h.profile.failWith = const ApiException(400, 'Username is already taken');
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'timur');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already taken'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget, reason: 'stays open — used to close as if saved');
    await shot(tester, 'edit_profile_error_dark');

    h.profile.failWith = null;
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'aygul_dev');
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(h.profile.saved.single['username'], 'aygul_dev');
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('new group sheet: guidance, chips, search, create enabled when valid', (tester) async {
    const people = [
      Contact(id: 2, username: 'timur', status: 'active', isContact: true, isBlocked: false, bio: 'Coffee, code, repeat'),
      Contact(id: 3, username: 'dana', status: 'active', isContact: true, isBlocked: false),
      Contact(id: 4, username: 'aslan', status: 'active', isContact: true, isBlocked: false),
    ];
    await pump(
      tester,
      Builder(builder: (context) => Center(child: ElevatedButton(onPressed: () => showCreateGroupModal(context), child: const Text('open')))),
      contacts: people,
      pushed: false,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose at least one person'), findsOneWidget);
    // alphabetical
    final names = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => ['aslan', 'dana', 'timur'].contains(d)).toList();
    expect(names, ['aslan', 'dana', 'timur']);

    await tester.tap(find.text('dana'));
    await tester.tap(find.text('timur'));
    await tester.pumpAndSettle();
    expect(find.text('Give your group a name'), findsOneWidget);
    expect(find.text('dana'), findsNWidgets(2), reason: 'row + chip');

    await tester.enterText(find.widgetWithText(TextField, 'Group name'), 'Weekend trip');
    await tester.pumpAndSettle();
    expect(find.text('2 people selected'), findsOneWidget);
    await shot(tester, 'new_group_dark');

    await tester.enterText(find.widgetWithText(TextField, 'Search contacts'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No one named'), findsOneWidget);

    // removing via the chip
    await tester.enterText(find.widgetWithText(TextField, 'Search contacts'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close_rounded).first); // dana's chip
    await tester.pumpAndSettle();
    expect(find.text('1 person selected'), findsOneWidget);
  });
}
