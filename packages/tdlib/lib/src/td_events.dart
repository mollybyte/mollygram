import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'generated/td_api.dart';
import 'td_json.dart';
import 'td_object.dart';

/// An object received from `td_receive`.
sealed class TdEvent {
  const TdEvent(this.clientId, this.requestId);

  /// The `@client_id`, or 0 if TDLib did not specify one.
  final int clientId;

  /// The `@extra` of the request this responds to, or `null` for updates.
  final int? requestId;
}

/// A response or update decoded into a td_api object.
final class TdReceived extends TdEvent {
  const TdReceived(super.clientId, super.requestId, this.object);

  final TdObject object;
}

/// A string from TDLib that could not be decoded.
///
/// The receive loop keeps running when this happens.
final class TdUndecodable extends TdEvent {
  const TdUndecodable(super.clientId, super.requestId, this.raw, this.error);

  final String raw;
  final String error;
}

/// Decodes a string from `td_receive`.
///
/// Never throws: anything that cannot be decoded becomes a [TdUndecodable].
TdEvent decodeTdEvent(String raw) {
  var clientId = 0;
  int? requestId;
  try {
    final json = jsonDecode(raw) as Map<String, Object?>;
    clientId = (json['@client_id'] as num?)?.toInt() ?? 0;
    requestId = (json['@extra'] as num?)?.toInt();
    return TdReceived(clientId, requestId, tdFromJson(json));
  } catch (e) {
    return TdUndecodable(clientId, requestId, raw, e.toString());
  }
}

/// Runs the `td_receive` loop.
///
/// Reads batches of up to [batchSize] objects, decodes them and passes them
/// to [emit]. Yields to the event loop between iterations so the isolate can
/// receive the stop command.
Future<void> runTdReceiveLoop(
  TdJson td,
  void Function(List<TdEvent>) emit, {
  required bool Function() isStopped,
  double timeout = 1.0,
  Duration idleDelay = Duration.zero,
  int batchSize = 64,
}) async {
  while (!isStopped()) {
    final first = td.receive(timeout);
    if (first == null) {
      await Future<void>.delayed(idleDelay);
      continue;
    }
    final batch = [decodeTdEvent(first)];
    while (batch.length < batchSize) {
      final next = td.receive(0);
      if (next == null) break;
      batch.add(decodeTdEvent(next));
    }
    emit(batch);
    await Future<void>.delayed(Duration.zero);
  }
}

/// A source of TDLib events.
abstract interface class TdEventSource {
  Stream<List<TdEvent>> get events;

  /// Stops receiving. Once this completes, no more events arrive.
  Future<void> close();
}

/// Runs the receive loop in a separate isolate.
///
/// `td_receive` blocks its thread, and JSON and td_api objects are decoded
/// there as well, off the UI isolate.
final class IsolateTdEventSource implements TdEventSource {
  IsolateTdEventSource._(
    this._isolate,
    this._control,
    this._events,
    this._done,
  );

  /// Spawns the isolate.
  ///
  /// [open] is called inside it and must be sendable between isolates: a
  /// top-level function or a closure over simple values, such as the library
  /// path.
  static Future<IsolateTdEventSource> spawn(
    TdJson Function() open, {
    double timeout = 1.0,
  }) async {
    final port = ReceivePort('td_receive');
    final errors = ReceivePort('td_receive errors');
    final events = StreamController<List<TdEvent>>();
    final control = Completer<SendPort>();
    final done = Completer<void>();

    port.listen((message) {
      switch (message) {
        case final SendPort p:
          control.complete(p);
        case final List<TdEvent> batch:
          events.add(batch);
        case null:
          if (!control.isCompleted) {
            control.completeError(
              StateError('td_receive isolate exited before start'),
            );
          }
          port.close();
          errors.close();
          unawaited(events.close());
          done.complete();
      }
    });
    errors.listen((error) {
      final [description, stack] = error as List<Object?>;
      final failure = StateError('td_receive isolate: $description');
      final trace = StackTrace.fromString(stack as String? ?? '');
      if (control.isCompleted) {
        events.addError(failure, trace);
      } else {
        control.completeError(failure, trace);
      }
    });

    final isolate = await Isolate.spawn(
      _main,
      (port.sendPort, open, timeout),
      onError: errors.sendPort,
      onExit: port.sendPort,
      debugName: 'td_receive',
    );
    return IsolateTdEventSource._(isolate, await control.future, events, done);
  }

  final Isolate _isolate;
  final SendPort _control;
  final StreamController<List<TdEvent>> _events;
  final Completer<void> _done;

  @override
  Stream<List<TdEvent>> get events => _events.stream;

  @override
  Future<void> close() {
    if (!_done.isCompleted) _control.send(null);
    return _done.future;
  }

  /// Kills the isolate without waiting for `td_receive`.
  ///
  /// For emergencies only.
  void kill() => _isolate.kill(priority: Isolate.immediate);

  static Future<void> _main((SendPort, TdJson Function(), double) args) async {
    final (out, open, timeout) = args;
    final control = ReceivePort();
    var stopped = false;
    control.listen((_) {
      stopped = true;
      control.close();
    });
    // The library is opened before replying so that a load error reaches
    // spawn instead of getting lost in the event stream.
    final td = open();
    out.send(control.sendPort);
    await runTdReceiveLoop(
      td,
      out.send,
      isStopped: () => stopped,
      timeout: timeout,
    );
    // The isolate exit sends null via onExit.
  }
}

/// Runs the receive loop in the current isolate without blocking.
///
/// Intended for tests and tools.
final class InlineTdEventSource implements TdEventSource {
  InlineTdEventSource(
    TdJson td, {
    Duration pollInterval = const Duration(milliseconds: 1),
  }) {
    _loop = runTdReceiveLoop(
      td,
      _events.add,
      isStopped: () => _stopped,
      timeout: 0,
      idleDelay: pollInterval,
    );
  }

  final _events = StreamController<List<TdEvent>>();
  late final Future<void> _loop;
  var _stopped = false;

  @override
  Stream<List<TdEvent>> get events => _events.stream;

  @override
  Future<void> close() async {
    _stopped = true;
    await _loop;
    await _events.close();
  }
}
