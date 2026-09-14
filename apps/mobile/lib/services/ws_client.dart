import "dart:async";
import "dart:convert";
import "package:web_socket_channel/web_socket_channel.dart";
import "api_client.dart";

class WsClient {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  Future<void> connect() async {
    final token = await ApiClient.getToken();
    if (token == null) return;
    _channel = WebSocketChannel.connect(Uri.parse("${ApiClient.wsUrl}?token=$token"));
    _channel!.stream.listen(
      (event) {
        _controller.add(jsonDecode(event));
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
