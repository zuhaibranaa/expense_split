import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/environment.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _streamController =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _streamController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void connect(int userId) {
    if (_isConnected) return;
    final uri = Uri.parse('${Environment.wsBaseUrl}/ws/$userId');
    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      debugPrint('WebSocket connected for user $userId');

      _channel!.stream.listen(
        (message) {
          debugPrint('WebSocket received: $message');
          try {
            final data = jsonDecode(message);
            _streamController.add(data);
          } catch (e) {
            debugPrint('Error decoding WS message: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _isConnected = false;
          _reconnect(userId);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _reconnect(userId);
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _reconnect(userId);
    }
  }

  void _reconnect(int userId) {
    Future.delayed(const Duration(seconds: 3), () {
      debugPrint('Attempting WS reconnection...');
      connect(userId);
    });
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _streamController.close();
  }
}

// Global instance (can be replaced with Provider/Riverpod later)
final webSocketService = WebSocketService();

final webSocketServiceProvider = Provider((ref) => webSocketService);

final webSocketEventsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.stream;
});
