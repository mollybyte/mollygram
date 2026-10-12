import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'generated/td_api.dart';
import 'td_json.dart';
import 'td_object.dart';

/// Объект, полученный из `td_receive`.
sealed class TdEvent {
  const TdEvent(this.clientId, this.requestId);

  /// `@client_id`; 0, если TDLib его не указал.
  final int clientId;

  /// `@extra` запроса, на который это ответ; `null` для обновлений.
  final int? requestId;
}

/// Ответ или обновление, разобранное в объект td_api.
final class TdReceived extends TdEvent {
  const TdReceived(super.clientId, super.requestId, this.object);

  final TdObject object;
}

/// Строку от TDLib не удалось разобрать. Цикл приёма при этом не падает.
final class TdUndecodable extends TdEvent {
  const TdUndecodable(super.clientId, super.requestId, this.raw, this.error);

  final String raw;
  final String error;
}

/// Разбирает строку от `td_receive`. Не бросает исключений: всё, что не
/// удалось разобрать, становится [TdUndecodable].
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

/// Цикл `td_receive`: читает пачки до [batchSize] объектов, разбирает их
/// и отдаёт в [emit]. Между итерациями уступает очередь событий, чтобы
/// изолят мог получить команду остановки.
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

/// Источник событий TDLib.
abstract interface class TdEventSource {
  Stream<List<TdEvent>> get events;

  /// Останавливает приём. После завершения событий больше не будет.
  Future<void> close();
}

/// Цикл приёма в отдельном изоляте: `td_receive` блокирует поток, а JSON
/// и объекты td_api разбираются там же, вне UI-изолята.
final class IsolateTdEventSource implements TdEventSource {
  IsolateTdEventSource._(
    this._isolate,
    this._control,
    this._events,
    this._done,
  );

  /// Запускает изолят. [open] вызывается внутри него и должен быть
  /// передаваемым между изолятами: функция верхнего уровня или замыкание
  /// над простыми значениями, например путём к библиотеке.
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

  /// Убить изолят, не дожидаясь `td_receive`. Только на случай аварии.
  void kill() => _isolate.kill(priority: Isolate.immediate);

  static Future<void> _main((SendPort, TdJson Function(), double) args) async {
    final (out, open, timeout) = args;
    final control = ReceivePort();
    var stopped = false;
    control.listen((_) {
      stopped = true;
      control.close();
    });
    // Библиотека открывается до ответа, чтобы ошибка загрузки дошла до
    // spawn, а не потерялась в потоке событий.
    final td = open();
    out.send(control.sendPort);
    await runTdReceiveLoop(
      td,
      out.send,
      isStopped: () => stopped,
      timeout: timeout,
    );
    // Выход изолята пришлёт null через onExit.
  }
}

/// Цикл приёма в текущем изоляте без блокировки: для тестов и утилит.
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
