import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_chat_app/core/network/api_client.dart';
import 'package:my_chat_app/core/utils/error_handler.dart';
import 'package:my_chat_app/features/chat/domain/entities/message.dart';
import 'package:my_chat_app/features/chat/presentation/providers/chat_provider.dart';

/// What happened to one queued message.
class SendOutcome {
  final int chatId;
  final int tempId;

  /// The stored message on success.
  final Message? sent;

  /// Readable reason on failure (null when cancelled or sent).
  final String? error;
  final bool cancelled;

  const SendOutcome({
    required this.chatId,
    required this.tempId,
    this.sent,
    this.error,
    this.cancelled = false,
  });
}

class _Job {
  _Job.text(this.temp)
    : bytes = null,
      filename = null,
      mimeType = null;
  _Job.file(this.temp, this.bytes, this.filename, this.mimeType);

  Message temp;
  final Uint8List? bytes;
  final String? filename;
  final String? mimeType;
  final Completer<void> abort = Completer<void>();

  bool get isFile => bytes != null;
  int get id => temp.id;
}

/// Outgoing messages, the way Telegram does it:
///
///  • **Two lanes.** Text goes out on its own lane, so typing "on my way"
///    is never stuck behind a 40 MB video. Files share one lane and upload
///    ONE AT A TIME, in the order they were picked — full bandwidth for each,
///    and they arrive in order.
///  • **App-level, not screen-level.** The queue outlives the chat screen:
///    leave the conversation (or open another) and uploads keep going;
///    come back and the pending bubbles are still there with live progress.
///  • Each lane is strictly sequential → messages can never be stored out of
///    order, which concurrent requests could not guarantee.
///
/// State = pending messages per chat (waiting, uploading or failed).
class SendQueue extends Notifier<Map<int, List<Message>>> {
  final Queue<_Job> _textLane = Queue();
  final Queue<_Job> _fileLane = Queue();

  /// Failed jobs are kept (with their bytes) so "retry" needs no re-picking.
  final Map<int, _Job> _failed = {};
  _Job? _activeFile;
  bool _textBusy = false;
  bool _fileBusy = false;

  final _outcomes = StreamController<SendOutcome>.broadcast();
  Stream<SendOutcome> get outcomes => _outcomes.stream;

  @override
  Map<int, List<Message>> build() {
    ref.onDispose(_outcomes.close);
    return const {};
  }

  List<Message> pendingFor(int chatId) => state[chatId] ?? const [];

  // ── Public API ───────────────────────────────────────────────────────────

  void enqueueText(Message temp) {
    _put(temp);
    _textLane.add(_Job.text(temp));
    _drainText();
  }

  void enqueueFile(
    Message temp,
    Uint8List bytes,
    String filename,
    String mimeType,
  ) {
    _put(temp);
    _fileLane.add(_Job.file(temp, bytes, filename, mimeType));
    _drainFiles();
  }

  /// Cancels a waiting or in-flight upload, or discards a failed message.
  void cancel(int tempId) {
    final failed = _failed.remove(tempId);
    if (failed != null) {
      _remove(failed.temp);
      return;
    }
    if (_activeFile?.id == tempId) {
      // The in-flight request is aborted; _runFile reports the outcome
      if (!_activeFile!.abort.isCompleted) _activeFile!.abort.complete();
      return;
    }
    for (final lane in [_fileLane, _textLane]) {
      final job = lane.where((j) => j.id == tempId).firstOrNull;
      if (job == null) continue;
      lane.remove(job);
      _remove(job.temp);
      _outcomes.add(
        SendOutcome(chatId: job.temp.chatId, tempId: tempId, cancelled: true),
      );
      return;
    }
  }

  void retry(int tempId) {
    final job = _failed.remove(tempId);
    if (job == null) return;
    final fresh = job.temp.copyWith(
      status: job.isFile ? MessageStatus.uploading : MessageStatus.sent,
      uploadedBytes: 0,
    );
    _put(fresh);
    if (job.isFile) {
      _fileLane.add(_Job.file(fresh, job.bytes, job.filename, job.mimeType));
      _drainFiles();
    } else {
      _textLane.add(_Job.text(fresh));
      _drainText();
    }
  }

  /// Drop everything (logout).
  void clear() {
    if (_activeFile != null && !_activeFile!.abort.isCompleted) {
      _activeFile!.abort.complete();
    }
    _textLane.clear();
    _fileLane.clear();
    _failed.clear();
    state = const {};
  }

  // ── Lanes ────────────────────────────────────────────────────────────────

  Future<void> _drainText() async {
    if (_textBusy) return;
    _textBusy = true;
    try {
      while (_textLane.isNotEmpty) {
        final job = _textLane.removeFirst();
        try {
          final sent = await ref
              .read(chatRepositoryProvider)
              .sendMessage(
                chatId: job.temp.chatId,
                text: job.temp.text!,
                replyTo: job.temp.replyTo,
              );
          _succeed(job, sent);
        } catch (e) {
          _fail(job, e);
        }
      }
    } finally {
      _textBusy = false;
    }
  }

  Future<void> _drainFiles() async {
    if (_fileBusy) return;
    _fileBusy = true;
    try {
      while (_fileLane.isNotEmpty) {
        final job = _fileLane.removeFirst();
        _activeFile = job;
        await _runFile(job);
        _activeFile = null;
      }
    } finally {
      _fileBusy = false;
    }
  }

  Future<void> _runFile(_Job job) async {
    var lastPercent = -1;
    try {
      final sent = await ref
          .read(chatRepositoryProvider)
          .sendFileMessage(
            chatId: job.temp.chatId,
            bytes: job.bytes!,
            filename: job.filename!,
            mimeType: job.mimeType!,
            replyToId: job.temp.replyTo?.id,
            abortTrigger: job.abort.future,
            onProgress: (sent, total) {
              // The socket reports every ~64KB chunk. Rebuilding the chat for
              // each one janks the list; whole percents are all a bar shows.
              final percent = total <= 0 ? 0 : (sent * 100 ~/ total);
              if (percent == lastPercent) return;
              lastPercent = percent;
              // `total` includes multipart framing; clamp to the file size
              final shown = sent > job.bytes!.length ? job.bytes!.length : sent;
              job.temp = job.temp.copyWith(uploadedBytes: shown);
              _put(job.temp);
            },
          );
      _succeed(job, sent);
    } on UploadCancelledException {
      _remove(job.temp);
      _outcomes.add(
        SendOutcome(chatId: job.temp.chatId, tempId: job.id, cancelled: true),
      );
    } catch (e) {
      _fail(job, e);
    }
  }

  void _succeed(_Job job, Message sent) {
    _remove(job.temp);
    _outcomes.add(
      SendOutcome(chatId: job.temp.chatId, tempId: job.id, sent: sent),
    );
  }

  void _fail(_Job job, Object error) {
    if (kDebugMode) debugPrint('send failed (${job.id}): $error');
    job.temp = job.temp.copyWith(status: MessageStatus.error);
    _failed[job.id] = job;
    _put(job.temp);
    _outcomes.add(
      SendOutcome(
        chatId: job.temp.chatId,
        tempId: job.id,
        error: ErrorHandler.getReadableErrorMessage(error),
      ),
    );
  }

  // ── State helpers ────────────────────────────────────────────────────────

  void _put(Message message) {
    final list = [...pendingFor(message.chatId)];
    final index = list.indexWhere((m) => m.id == message.id);
    if (index == -1) {
      list.add(message);
    } else {
      list[index] = message;
    }
    state = {...state, message.chatId: list};
  }

  void _remove(Message message) {
    final list = pendingFor(message.chatId)
        .where((m) => m.id != message.id)
        .toList();
    final next = {...state};
    if (list.isEmpty) {
      next.remove(message.chatId);
    } else {
      next[message.chatId] = list;
    }
    state = next;
  }
}

final sendQueueProvider =
    NotifierProvider<SendQueue, Map<int, List<Message>>>(SendQueue.new);
