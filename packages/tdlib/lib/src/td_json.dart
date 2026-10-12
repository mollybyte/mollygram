/// The td_json interface: the four functions of the TDLib C API.
///
/// Implemented via dart:ffi ([TdJsonFfi]) and by fakes in tests.
abstract interface class TdJson {
  /// `td_create_client_id`.
  int createClientId();

  /// `td_send`. Thread-safe; may be called from any isolate.
  void send(int clientId, String request);

  /// `td_receive`. Blocks the thread for up to [timeout] seconds, so it is
  /// called only from a background isolate. Returns `null` if nothing arrived
  /// in that time.
  String? receive(double timeout);

  /// `td_execute`: synchronous requests that need no client.
  String? execute(String request);
}
