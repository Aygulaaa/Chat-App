import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/chat/date_divider.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_bubble.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_list.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/reply_quote.dart';

const me = 1;
const them = 2;

Message msg(
  int id, {
  int sender = them,
  String? text,
  DateTime? at,
  ReplyPreview? replyTo,
  MessageStatus status = MessageStatus.sent,
}) => Message(
  id: id,
  chatId: 1,
  senderId: sender,
  text: text ?? 'message $id',
  createdAt: at ?? DateTime(2026, 3, 1, 10).add(Duration(minutes: id)),
  replyTo: replyTo,
  status: status,
);

/// Real router + ScreenUtil + theme, because the widgets under test use all three.
Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) async {
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
      builder: (_, _) => MaterialApp.router(
        routerConfig: router,
        theme: theme ?? AppTheme.dark,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('reply bubble', () {
    testWidgets('shows the quote, labels my own message "You", tap reports the id', (tester) async {
      int? tapped;
      await pump(
        tester,
        MessageBubble(
          message: msg(
            10,
            text: 'yes!',
            replyTo: const ReplyPreview(id: 4, senderId: me, senderName: 'me', text: 'coffee?'),
          ),
          isMe: false,
          currentUserId: me,
          time: '10:10',
          onQuoteTap: (id) => tapped = id,
        ),
      );

      expect(find.text('coffee?'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('yes!'), findsOneWidget);

      await tester.tap(find.byType(ReplyQuote));
      expect(tapped, 4);
    });

    testWidgets('renders in the light theme too', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: msg(
            10,
            replyTo: const ReplyPreview(id: 4, senderId: them, senderName: 'aygul', fileType: MessageType.image),
          ),
          isMe: true,
          currentUserId: me,
          time: '10:10',
        ),
        theme: AppTheme.light,
      );
      expect(find.text('aygul'), findsOneWidget);
      expect(find.text('Photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('swipe past the threshold replies; a small nudge does not', (tester) async {
      var replies = 0;
      await pump(
        tester,
        MessageBubble(message: msg(1), isMe: false, time: '10:01', onReply: () => replies++),
      );

      await tester.drag(find.text('message 1'), const Offset(25, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);

      await tester.drag(find.text('message 1'), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
    });

    testWidgets('my own messages swipe LEFT', (tester) async {
      var replies = 0;
      await pump(
        tester,
        MessageBubble(message: msg(1, sender: me), isMe: true, time: '10:01', onReply: () => replies++),
      );
      await tester.drag(find.text('message 1'), const Offset(160, 0)); // wrong way
      await tester.pumpAndSettle();
      expect(replies, 0);
      await tester.drag(find.text('message 1'), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(replies, 1);
    });

    testWidgets('long-press menu has Reply and it fires', (tester) async {
      var replies = 0;
      await pump(
        tester,
        MessageBubble(message: msg(1), isMe: false, time: '10:01', onReply: () => replies++),
      );
      await tester.longPress(find.text('message 1'));
      await tester.pumpAndSettle();
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Delete'), findsNothing, reason: "not my message");

      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();
      expect(replies, 1);
      expect(find.text('Reply'), findsNothing, reason: 'menu closed');
    });

    testWidgets('an unsent message cannot be replied to, and offers retry', (tester) async {
      var replies = 0, retries = 0;
      final pending = Message(
        id: DateTime.now().microsecondsSinceEpoch,
        chatId: 1,
        senderId: me,
        text: 'offline msg',
        createdAt: DateTime.now(),
        status: MessageStatus.error,
      );
      await pump(
        tester,
        MessageBubble(
          message: pending,
          isMe: true,
          time: '10:01',
          onReply: () => replies++,
          onRetry: () => retries++,
        ),
      );
      expect(find.textContaining('Tap to retry'), findsOneWidget);

      await tester.drag(find.text('offline msg'), const Offset(-160, 0));
      await tester.pumpAndSettle();
      expect(replies, 0);

      await tester.tap(find.text('offline msg'));
      expect(retries, 1);
    });
  });

  group('message list', () {
    testWidgets('tapping a quote scrolls far up to the original', (tester) async {
      // Newest first. Message 80 (index 0) replies to message 1 (far off-screen).
      final messages = [
        msg(80, replyTo: const ReplyPreview(id: 1, senderId: them, senderName: 'aygul', text: 'THE ORIGINAL')),
        for (var id = 79; id >= 1; id--) msg(id, text: id == 1 ? 'THE ORIGINAL' : null),
      ];
      await pump(
        tester,
        MessageList(messages: messages, userId: me, isTyping: false),
      );

      // Only the quote shows that text; the real message isn't built yet
      expect(find.text('THE ORIGINAL'), findsOneWidget);

      await tester.tap(find.byType(ReplyQuote));
      await tester.pumpAndSettle();

      expect(find.text('THE ORIGINAL'), findsOneWidget);
      expect(find.byType(ReplyQuote), findsNothing, reason: 'scrolled away from the reply');
      final bubble = tester.widget<MessageBubble>(
        find.ancestor(of: find.text('THE ORIGINAL'), matching: find.byType(MessageBubble)),
      );
      expect(bubble.message.id, 1);

      // highlight clears by itself
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    });

    testWidgets('quotes from blocked users are hidden', (tester) async {
      await pump(
        tester,
        MessageList(
          messages: [
            msg(2, replyTo: const ReplyPreview(id: 1, senderId: 66, senderName: 'blocked', text: 'secret')),
          ],
          userId: me,
          isTyping: false,
          hiddenQuoteAuthorIds: const {66},
        ),
      );
      expect(find.text('secret'), findsNothing);
      expect(find.text('message 2'), findsOneWidget);
    });

    testWidgets('same day-of-month in different months gets a divider (regression)', (tester) async {
      await pump(
        tester,
        MessageList(
          messages: [
            msg(2, at: DateTime(2026, 2, 5, 9)),
            msg(1, at: DateTime(2026, 1, 5, 9)),
          ],
          userId: me,
          isTyping: false,
        ),
      );
      expect(find.byType(DateDivider), findsNWidgets(2));
    });

    testWidgets('asks for older history near the top', (tester) async {
      var loads = 0;
      await pump(
        tester,
        MessageList(
          messages: [for (var id = 60; id >= 1; id--) msg(id)],
          userId: me,
          isTyping: false,
          onLoadMore: () => loads++,
        ),
      );
      expect(loads, 0, reason: 'not while reading the newest messages');
      await tester.fling(find.byType(ListView), const Offset(0, 6000), 8000);
      await tester.pumpAndSettle();
      expect(loads, greaterThan(0));
      // and the jump-to-latest button is now offered
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('empty conversation has a friendly state', (tester) async {
      await pump(tester, const MessageList(messages: [], userId: me, isTyping: false));
      expect(find.text('No messages yet'), findsOneWidget);
    });
  });
}
