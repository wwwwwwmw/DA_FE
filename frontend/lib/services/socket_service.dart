import 'package:socket_io_client/socket_io_client.dart' as sio;

class SocketService {
  sio.Socket? _socket;

  void connect({
    required String baseUrl,
    String? token,
    void Function(dynamic data)? onNotification,
    void Function(dynamic data)? onDataUpdated,
  }) {
    disconnect();
    _socket = sio.io(
      baseUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNew()
          .setAuth(token != null ? {'token': token} : {})
          .build(),
    );

    _socket!.onConnect((_) {});
    _socket!.on('receiveNotification', (data) {
      if (onNotification != null) onNotification(data);
    });
    _socket!.on('dataUpdated', (data) {
      if (onDataUpdated != null) onDataUpdated(data);
    });
    _socket!.onDisconnect((_) {});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
