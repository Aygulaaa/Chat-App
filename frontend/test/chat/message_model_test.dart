import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/features/auth/data/models/user_model.dart';
import 'package:my_chat_app/features/chat/data/models/chat_model.dart';
import 'package:my_chat_app/features/chat/data/models/message_model.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';

void main() {
  group('MessageModel replies', () {
    final json = {
      'id': 42,
      'chatId': '7', // bigint columns arrive as strings
      'senderId': 3,
      'text': 'sounds good',
      'createdAt': '2026-01-05T10:00:00.000Z',
      'replyToId': 40,
      'replyTo': {
        'id': 40,
        'senderId': 9,
        'senderName': 'aygul',
        'text': 'lunch at 1?',
        'fileType': null,
        'originalName': null,
      },
    };

    test('parses the quoted message', () {
      final m = MessageModel.fromJson(json);
      expect(m.chatId, 7);
      expect(m.replyTo, isNotNull);
      expect(m.replyTo!.id, 40);
      expect(m.replyTo!.senderName, 'aygul');
      expect(m.replyTo!.summary, 'lunch at 1?');
    });

    test('no replyTo → null, never throws', () {
      final m = MessageModel.fromJson({...json, 'replyTo': null});
      expect(m.replyTo, isNull);
      expect(MessageModel.fromJson({...json, 'replyTo': 'junk'}).replyTo, isNull);
      expect(MessageModel.fromJson({...json, 'createdAt': 'not a date'}).id, 42);
    });

    test('quote survives the cache round trip', () {
      final restored = MessageModel.fromJson(MessageModel.fromJson(json).toJson());
      expect(restored.replyTo, MessageModel.fromJson(json).replyTo);
    });

    test('a copyWith()-ed message can still be cached (regression)', () {
      // copyWith returns a plain Message. The cache writer used to keep only
      // MessageModel instances, silently dropping every updated message.
      final Message updated = MessageModel.fromJson(json).copyWith(
        status: MessageStatus.read,
        readAt: DateTime(2026, 1, 5, 12),
      );
      expect(updated, isNot(isA<MessageModel>()));
      final cached = MessageModel.fromEntity(updated).toJson();
      expect(cached['readAt'], isNotNull);
      expect(cached['replyTo'], isNotNull);
    });

    test('attachment quotes describe the file', () {
      const photo = ReplyPreview(id: 1, senderId: 1, fileType: MessageType.image);
      const doc = ReplyPreview(
        id: 1,
        senderId: 1,
        fileType: MessageType.pdf,
        originalName: 'cv.pdf',
      );
      expect(photo.summary, contains('Photo'));
      expect(doc.summary, contains('cv.pdf'));
    });

    test('pending ids and stable view keys', () {
      final temp = Message(
        id: DateTime.now().microsecondsSinceEpoch,
        chatId: 1,
        senderId: 1,
        createdAt: DateTime.now(),
      );
      expect(temp.isPending, isTrue);

      final confirmed = MessageModel.fromJson(json).copyWith(localId: temp.id);
      expect(confirmed.isPending, isFalse);
      expect(confirmed.viewKey, temp.id, reason: 'bubble keeps its identity');
      expect(confirmed.copyWith(clearReplyTo: true).replyTo, isNull);
    });
  });

  group('ChatModel cache', () {
    test('a chat that received a message is still cached (regression)', () {
      final chat = ChatModel.fromJson({
        'id': 1,
        'type': 'private',
        'unreadCount': 0,
        'participants': [
          {'id': 1, 'username': 'a'},
        ],
        'lastMessage': null,
      });
      final updated = chat.copyWith(
        unreadCount: 3,
        isMuted: true,
        lastMessage: Message(
          id: 5,
          chatId: 1,
          senderId: 1,
          text: 'hi',
          createdAt: DateTime(2026),
        ),
      );
      expect(updated, isNot(isA<ChatModel>()));

      final restored = ChatModel.fromJson(ChatModel.fromEntity(updated).toJson());
      expect(restored.unreadCount, 3);
      expect(restored.lastMessage?.text, 'hi');
      expect(restored.isMuted, isTrue, reason: 'mute used to be lost on restart');
      expect(restored.participants.first, isA<UserModel>());
    });
  });
}
