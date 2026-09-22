import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/common/entities/user_entity.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:my_chat_app/features/auth/presentation/providers/auth_state.dart';
import 'package:my_chat_app/features/chat/domain/entities/chat.dart';
import 'package:my_chat_app/features/chat/presentation/pages/group_profile_screen.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_notifier.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_state.dart';
import 'package:my_chat_app/features/contacts/domain/entities/contact.dart';
import 'package:my_chat_app/features/contacts/presentation/providers/contacts_provider.dart';

const _me = UserEntity(id: 1, username: 'aygul');
const _timur = UserEntity(id: 2, username: 'timur');
const _dana = UserEntity(id: 3, username: 'dana');

class FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(user: _me, token: 't');
}

class FakeChats extends ChatNotifier {
  FakeChats(this.createdBy);
  final int createdBy;
  final calls = <String>[];

  @override
  ChatState build() => ChatState(
    chats: [
      Chat(
        id: 7,
        name: 'Weekend trip',
        type: 'group',
        createdBy: createdBy,
        participants: const [_timur, _me],
        lastMessage: null,
        unreadCount: 0,
      ),
    ],
  );

  @override
  Future<void> addMember(int chatId, int userId) async {
    calls.add('add:$userId');
    final chat = state.chats.single;
    state = state.copyWith(
      chats: [
        chat.copyWith(participants: [...chat.participants, _dana]),
      ],
    );
  }

  @override
  Future<void> removeMember(int chatId, int userId) async =>
      calls.add('remove:$userId');

  @override
  Future<void> deleteGroup(int chatId) async => calls.add('delete');
}

class FakeContacts extends ContactsNotifier {
  @override
  Future<List<Contact>> build() async => const [
    Contact(id: 2, username: 'timur', status: 'active', isContact: true, isBlocked: false),
    Contact(id: 3, username: 'dana', status: 'active', isContact: true, isBlocked: false, bio: 'Hiking'),
  ];
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

Future<FakeChats> pump(WidgetTester tester, {required int createdBy}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final chats = FakeChats(createdBy);
  final router = GoRouter(
    initialLocation: '/group',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('ROOT'))),
      GoRoute(path: '/group', builder: (_, _) => const GroupProfileScreen(chatId: 7)),
    ],
  );
  final base = AppTheme.dark;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authProvider.overrideWith(FakeAuth.new),
      chatProvider.overrideWith(() => chats),
      contactsProvider.overrideWith(FakeContacts.new),
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
  await tester.pumpAndSettle();
  return chats;
}

Future<void> shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOTS'];
  if (dir == null) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$dir/$name.png'));
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('creator: members on the page, confirmed remove and delete', (tester) async {
    final chats = await pump(tester, createdBy: 1);
    await shot(tester, 'group_profile_dark');

    expect(find.text('Weekend trip'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('owner'), findsOneWidget);
    // No permanent bottom sheet any more — it is one scrolling page
    expect(find.byType(DraggableScrollableSheet), findsNothing);

    await tester.tap(find.byTooltip('Remove from group'));
    await tester.pumpAndSettle();
    expect(chats.calls, isEmpty, reason: 'asks first');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(chats.calls, ['remove:2']);

    await tester.tap(find.text('Delete Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(chats.calls, ['remove:2', 'delete']);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('non-creator cannot remove or delete', (tester) async {
    await pump(tester, createdBy: 2);
    expect(find.byTooltip('Remove from group'), findsNothing);
    expect(find.text('Delete Group'), findsNothing);
  });

  testWidgets('add members: only non-members listed, adding keeps the sheet open', (tester) async {
    final chats = await pump(tester, createdBy: 1);
    await tester.tap(find.text('Add Members'));
    await tester.pumpAndSettle();
    await shot(tester, 'add_members_dark');

    expect(find.text('dana'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget, reason: 'timur is already a member');

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(chats.calls, ['add:3']);
    expect(find.textContaining('already in this group'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('3 members'), findsOneWidget);
  });
}
