import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  IO.Socket? _socket;

  void connect({required String baseUrl, String? token, void Function(dynamic data)? onNotification}) {
    disconnect();
    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .enableForceNew()
        .setAuth(token != null ? {'token': token} : {})
        .build());

    _socket!.onConnect((_) {});
    _socket!.on('receiveNotification', (data) {
      if (onNotification != null) onNotification(data);
    });
    _socket!.onDisconnect((_) {});
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
