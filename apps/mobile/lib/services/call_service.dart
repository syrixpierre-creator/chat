import "dart:async";
import "dart:convert";
import "package:web_socket_channel/web_socket_channel.dart";
import "api_client.dart";

class CallService {
  static final CallService instance = CallService._internal();
  CallService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get callEvents => _controller.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    final token = await ApiClient.getToken();
    if (token == null) return;
    _channel = WebSocketChannel.connect(Uri.parse("${ApiClient.wsUrl}?token=$token"));
    _channel!.stream.listen(
      (event) {
        final decoded = jsonDecode(event);
        if (decoded is Map && decoded.containsKey("callEvent")) {
          _controller.add(Map<String, dynamic>.from(decoded));
        }
      },
      onError: (_) {},
      onDone: () {
        _channel = null;
      },
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
