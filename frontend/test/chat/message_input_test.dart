import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/core/theme/app_theme.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/widgets/message/message_input.dart';

Future<void> pump(WidgetTester tester, Widget input) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: Column(children: [const Spacer(), input])),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final target = Message(
    id: 5,
    chatId: 1,
    senderId: 2,
    text: 'are you coming tonight?',
    createdAt: DateTime(2026, 3, 1),
  );

  testWidgets('no reply bar by default; field grows to multiple lines', (tester) async {
    await pump(tester, const MessageInput(chatId: 1));
    expect(find.textContaining('Reply to'), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 5);
    expect(field.minLines, 1);
    expect(tester.takeException(), isNull, reason: 'recorder failure must not crash');
  });

  testWidgets('reply bar shows who and what, focuses the field, and can be cancelled', (tester) async {
    var cancelled = 0;
    Widget build(Message? replyingTo) => MessageInput(
      chatId: 1,
      replyingTo: replyingTo,
      replyAuthorLabel: 'aygul',
      onCancelReply: () => cancelled++,
    );

    await pump(tester, build(null));
    await pump(tester, build(target)); // user picked a message
    expect(find.text('Reply to aygul'), findsOneWidget);
    expect(find.text('are you coming tonight?'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);

    await tester.tap(find.byTooltip('Cancel reply'));
    expect(cancelled, 1);
  });

  testWidgets('blocked chats replace the input with an explanation', (tester) async {
    await pump(tester, const MessageInput(chatId: 1, isBlocked: true));
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('You blocked this user'), findsOneWidget);
  });
}
