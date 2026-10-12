import 'dart:convert';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';
import 'package:test/test.dart';

/// A [TdJson] created inside the background isolate: returns the given
/// strings, then blocks `receive` for the timeout like the real td_receive.
final class _ScriptedTdJson implements TdJson {
  _ScriptedTdJson(this._script);

  final List<String> _script;
  var _position = 0;

  @override
  int createClientId() => 1;

  @override
  void send(int clientId, String request) {}

  @override
  String? receive(double timeout) {
    if (_position < _script.length) return _script[_position++];
    final until = DateTime.now().add(
      Duration(microseconds: (timeout * 1e6).round()),
    );
    while (DateTime.now().isBefore(until)) {}
    return null;
  }

  @override
  String? execute(String request) => null;
}

void main() {
  test('isolate decodes objects and stops on close', () async {
    final script = [
      for (var i = 0; i < 200; i++)
        jsonEncode({
          '@type': 'updateOption',
          'name': 'n$i',
          'value': {'@type': 'optionValueInteger', 'value': '$i'},
          '@client_id': 1,
        }),
      '{broken',
      jsonEncode({'@type': 'ok', '@client_id': 1, '@extra': 7}),
    ];
    final source = await IsolateTdEventSource.spawn(
      () => _ScriptedTdJson(script),
      timeout: 0.05,
    );
    final events = <TdEvent>[];
    final batches = <int>[];
    final subscription = source.events.listen((batch) {
      batches.add(batch.length);
      events.addAll(batch);
    });

    while (events.length < script.length) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await source.close();
    await subscription.cancel();

    expect(batches.every((n) => n <= 64), isTrue);
    expect(batches.length, lessThan(script.length));
    final first = events.first as TdReceived;
    expect((first.object as UpdateOption).name, 'n0');
    expect(first.clientId, 1);
    expect(events[200], isA<TdUndecodable>());
    final last = events.last as TdReceived;
    expect(last.requestId, 7);
    expect(last.object, isA<Ok>());
  });

  test('an isolate startup error does not hang spawn', () async {
    await expectLater(
      IsolateTdEventSource.spawn(() => throw StateError('no libtdjson')),
      throwsA(isA<StateError>()),
    );
  });
}
