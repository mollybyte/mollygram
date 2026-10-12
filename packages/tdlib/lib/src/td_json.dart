/// Интерфейс td_json: четыре функции C API TDLib.
///
/// Есть реализация через dart:ffi ([TdJsonFfi]) и подмены в тестах.
abstract interface class TdJson {
  /// `td_create_client_id`.
  int createClientId();

  /// `td_send`. Потокобезопасна, вызывается из любого изолята.
  void send(int clientId, String request);

  /// `td_receive`. Блокирует поток до [timeout] секунд, поэтому вызывается
  /// только из фонового изолята. `null`, если за это время ничего не пришло.
  String? receive(double timeout);

  /// `td_execute`, синхронные запросы, которые не требуют клиента.
  String? execute(String request);
}
