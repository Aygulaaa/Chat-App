import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:my_chat_app/features/chat/presentation/providers/send_queue.dart';

/// A repository whose uploads only finish when the test says so.
class FakeRepo implements ChatRepository {
  final log = <String>[];
  final uploads = <String, Completer<void>>{};
  final progress = <String, void Function(int, int)>{};
  final failOnce = <String>{};
  int _nextId = 100;
  int concurrentUploads = 0, maxConcurrentUploads = 0;

  @override
  Future<Message> sendMessage({required int chatId, required String text, ReplyPreview? replyTo}) async {
    log.add('text:$text:start');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (failOnce.remove(text)) throw const ApiException(ApiException.noConnection, 'offline');
    log.add('text:$text:done');
    return Message(id: _nextId++, chatId: chatId, senderId: 1, text: text, createdAt: DateTime.now());
  }

  @override
  Future<Message> sendFileMessage({
    required int chatId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    int? replyToId,
    Function(int sent, int total)? onProgress,
    Future<void>? abortTrigger,
  }) async {
    log.add('file:$filename:start');
    concurrentUploads++;
    if (concurrentUploads > maxConcurrentUploads) maxConcurrentUploads = concurrentUploads;
    final gate = uploads.putIfAbsent(filename, Completer<void>.new);
    progress[filename] = (s, t) => onProgress?.call(s, t);
    try {
      await Future.any([
        gate.future,
        if (abortTrigger != null) abortTrigger.then((_) => throw const UploadCancelledException()),
      ]);
      if (failOnce.remove(filename)) throw const ApiException(500, 'boom');
      log.add('file:$filename:done');
      return Message(id: _nextId++, chatId: chatId, senderId: 1, originalName: filename, fileType: MessageType.image, createdAt: DateTime.now());
    } finally {
      concurrentUploads--;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

int _id = DateTime.now().microsecondsSinceEpoch;
Message temp({String? text, String? file, int chatId = 1}) => Message(
  id: _id++,
  chatId: chatId,
  senderId: 1,
  text: text ?? file,
  originalName: file,
  fileType: file == null ? MessageType.text : MessageType.image,
  fileSize: file == null ? null : 1000,
  status: file == null ? MessageStatus.sent : MessageStatus.uploading,
  createdAt: DateTime.now(),
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late FakeRepo repo;
  late ProviderContainer container;
  late SendQueue queue;
  late List<SendOutcome> outcomes;

  setUp(() {
    repo = FakeRepo();
    container = ProviderContainer(overrides: [chatRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(container.dispose);
    queue = container.read(sendQueueProvider.notifier);
    outcomes = [];
    queue.outcomes.listen(outcomes.add);
  });

  void enqueueFile(Message m) => queue.enqueueFile(m, Uint8List(1000), m.originalName!, 'image/jpeg');

  test('text is never stuck behind an upload (separate lanes)', () async {
    enqueueFile(temp(file: 'big.mp4'));
    queue.enqueueText(temp(text: 'on my way'));
    await settle();

    expect(repo.log, containsAllInOrder(['file:big.mp4:start', 'text:on my way:done']));
    expect(repo.log, isNot(contains('file:big.mp4:done')), reason: 'upload still running');
    expect(outcomes.single.sent?.text, 'on my way');
  });

  test('files upload ONE at a time, in the order they were picked', () async {
    for (final f in ['1.jpg', '2.jpg', '3.jpg']) {
      enqueueFile(temp(file: f));
    }
    await settle();
    expect(repo.log, ['file:1.jpg:start'], reason: '2 and 3 wait their turn');
    expect(container.read(sendQueueProvider)[1], hasLength(3), reason: 'all three show as pending bubbles');

    repo.uploads['1.jpg']!.complete();
    await settle();
    repo.uploads['2.jpg']!.complete();
    await settle();
    repo.uploads['3.jpg']!.complete();
    await settle();

    expect(repo.maxConcurrentUploads, 1);
    expect(repo.log.where((l) => l.endsWith(':done')), ['file:1.jpg:done', 'file:2.jpg:done', 'file:3.jpg:done']);
    expect(container.read(sendQueueProvider), isEmpty);
  });

  test('texts keep their order even when sent rapidly', () async {
    for (final t in ['a', 'b', 'c']) {
      queue.enqueueText(temp(text: t));
    }
    await settle();
    expect(repo.log, ['text:a:start', 'text:a:done', 'text:b:start', 'text:b:done', 'text:c:start', 'text:c:done']);
  });

  test('progress is published per message, clamped to the file size', () async {
    final m = temp(file: 'v.mp4');
    enqueueFile(m);
    await settle();
    repo.progress['v.mp4']!(500, 1200); // total includes multipart framing
    expect(container.read(sendQueueProvider)[1]!.single.uploadedBytes, 500);
    repo.progress['v.mp4']!(1200, 1200);
    expect(container.read(sendQueueProvider)[1]!.single.uploadedBytes, 1000);
    repo.uploads['v.mp4']!.complete();
  });

  test('cancel: a waiting file is dropped, an in-flight one is aborted, the next proceeds', () async {
    final a = temp(file: 'a.jpg'), b = temp(file: 'b.jpg'), c = temp(file: 'c.jpg');
    [a, b, c].forEach(enqueueFile);
    await settle();

    queue.cancel(b.id); // still waiting
    queue.cancel(a.id); // uploading right now
    await settle();

    expect(outcomes.where((o) => o.cancelled).map((o) => o.tempId), unorderedEquals([a.id, b.id]));
    expect(repo.log, contains('file:c.jpg:start'));
    expect(repo.log, isNot(contains('file:b.jpg:start')), reason: 'never uploaded');
    repo.uploads['c.jpg']!.complete();
    await settle();
    expect(outcomes.last.sent?.originalName, 'c.jpg');
  });

  test('a failure keeps the message (and its bytes) for retry, and does not block the lane', () async {
    final a = temp(file: 'a.jpg'), b = temp(file: 'b.jpg');
    repo.failOnce.add('a.jpg');
    enqueueFile(a);
    enqueueFile(b);
    await settle();
    repo.uploads['a.jpg']!.complete();
    await settle();

    final failed = outcomes.firstWhere((o) => o.tempId == a.id);
    expect(failed.error, contains("it's not you"), reason: 'readable, not "ApiException"');
    expect(container.read(sendQueueProvider)[1]!.firstWhere((m) => m.id == a.id).status, MessageStatus.error);
    expect(repo.log, contains('file:b.jpg:start'), reason: 'queue moved on');

    repo.uploads['b.jpg']!.complete();
    await settle();
    repo.uploads.remove('a.jpg');
    queue.retry(a.id);
    await settle();
    repo.uploads['a.jpg']!.complete();
    await settle();
    expect(outcomes.last.sent?.originalName, 'a.jpg');
    expect(container.read(sendQueueProvider), isEmpty);
  });

  test('failed text can be retried too', () async {
    final m = temp(text: 'hello');
    repo.failOnce.add('hello');
    queue.enqueueText(m);
    await settle();
    expect(outcomes.single.error, contains('Wi-Fi'));
    queue.retry(m.id);
    await settle();
    expect(outcomes.last.sent?.text, 'hello');
  });

  test('chats are independent; clear() empties everything (logout)', () async {
    enqueueFile(temp(file: 'x.jpg', chatId: 1));
    enqueueFile(temp(file: 'y.jpg', chatId: 2));
    await settle();
    expect(container.read(sendQueueProvider).keys, unorderedEquals([1, 2]));
    queue.clear();
    await settle();
    expect(container.read(sendQueueProvider), isEmpty);
  });
}
