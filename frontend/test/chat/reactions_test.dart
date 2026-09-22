import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reaction_row.dart';

const me = 1;
const them = 2;

Message msg({
  int id = 10,
  int sender = them,
  String text = 'sounds good',
  MessageType fileType = MessageType.text,
  String? fileUrl,
  List<MessageReaction> reactions = const [],
}) => Message(
  id: id,
  chatId: 1,
  senderId: sender,
  text: text,
  fileType: fileType,
  fileUrl: fileUrl,
  createdAt: DateTime(2026, 3, 1, 10),
  reactions: reactions,
);

Future<void> pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: child)),
    ],
  );
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (_, _) =>
          MaterialApp.router(routerConfig: router, theme: AppTheme.dark),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('reaction parsing', () {
    test('reads the list the server sends', () {
      final m = MessageModel.fromJson({
        'id': 5,
        'chatId': 1,
        'senderId': 2,
        'text': 'hi',
        'createdAt': '2026-01-05T10:00:00.000Z',
        'reactions': [
          {'userId': '7', 'emoji': '❤️'},
          {'userId': 8, 'emoji': '👍'},
        ],
      });
      expect(m.reactions.length, 2);
      expect(m.reactions.first.userId, 7);
      expect(m.reactionOf(8), '👍');
      expect(m.reactionOf(99), isNull);
      expect(m.reactionOf(null), isNull);
    });

    test('missing, malformed or empty rows are dropped, never thrown on', () {
      Message parse(dynamic raw) => MessageModel.fromJson({
        'id': 5,
        'chatId': 1,
        'senderId': 2,
        'createdAt': '2026-01-05T10:00:00.000Z',
        'reactions': raw,
      });
      expect(parse(null).reactions, isEmpty);
      expect(parse('junk').reactions, isEmpty);
      expect(parse([
        {'userId': null, 'emoji': '👍'},
        {'userId': 3, 'emoji': ''},
        'nonsense',
      ]).reactions, isEmpty);
    });

    test('reactions survive the cache round trip', () {
      final original = msg(
        reactions: const [MessageReaction(userId: 7, emoji: '🔥')],
      );
      final restored = MessageModel.fromJson(
        MessageModel.fromEntity(original).toJson(),
      );
      expect(restored.reactions, original.reactions);
    });
  });

  group('reaction pills', () {
    testWidgets('a reaction rides on the bubble, not as its own message', (
      tester,
    ) async {
      await pump(
        tester,
        MessageBubble(
          message: msg(
            reactions: const [MessageReaction(userId: me, emoji: '❤️')],
          ),
          isMe: false,
          currentUserId: me,
          time: '10:10',
        ),
      );

      // The emoji is inside the same bubble as the text it belongs to
      expect(find.text('❤️'), findsOneWidget);
      expect(find.text('sounds good'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MessageBubble),
          matching: find.byType(ReactionRow),
        ),
        findsOneWidget,
      );
    });

    testWidgets('same emoji from several people shows one pill with a count', (
      tester,
    ) async {
      await pump(
        tester,
        MessageBubble(
          message: msg(
            reactions: const [
              MessageReaction(userId: me, emoji: '👍'),
              MessageReaction(userId: them, emoji: '👍'),
              MessageReaction(userId: 3, emoji: '😮'),
            ],
          ),
          isMe: true,
          currentUserId: me,
          time: '10:10',
        ),
      );

      expect(find.text('👍'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('😮'), findsOneWidget);
      // A single reaction carries no count next to it
      expect(find.text('1'), findsNothing);
    });

    testWidgets('tapping a pill reports the emoji back', (tester) async {
      final tapped = <String>[];
      await pump(
        tester,
        MessageBubble(
          message: msg(
            reactions: const [MessageReaction(userId: them, emoji: '🔥')],
          ),
          isMe: false,
          currentUserId: me,
          time: '10:10',
          onReact: tapped.add,
        ),
      );

      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(tapped, ['🔥']);
    });

    testWidgets('no reactions → nothing drawn', (tester) async {
      await pump(
        tester,
        MessageBubble(message: msg(), isMe: false, currentUserId: me, time: '10:10'),
      );
      expect(find.byType(ReactionRow), findsNothing);
    });
  });
}
