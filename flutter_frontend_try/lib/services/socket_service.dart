import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Clase que maneja la conexión y comunicación con el servidor WebSocket
class SocketService {
  late socket_io.Socket socket; // Instancia del socket
  final Function(String, String)
  onMessage; // Callback para manejar mensajes entrantes
  final Function(bool)
  onConnectionStatusChange; // Callback para cambio de estado
  int reconnectAttempts = 0; // Contador de intentos de reconexión
  static const int maxReconnectAttempts = 5; // Máximo número de intentos

  // Constructor
  SocketService({
    required this.onMessage,
    required this.onConnectionStatusChange,
  });

  // Método que inicializa la conexión con el servidor WebSocket
  void initialize() {
    final String serverUrl =
        dotenv.env['SOCKET_SERVER'] ?? 'http://localhost:3000';
    final String jwtSecret =
        dotenv.env['JWT_SECRET'] ??
        'default-secret'; // Valor por defecto si no está en .env

    // Genera un token JWT
    final jwt = JWT({'user': 'cliente'}); // Ajusta los datos según necesidad
    final token = jwt.sign(SecretKey(jwtSecret));

    socket = socket_io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'token': token},
    });

    // Evento cuando la conexión es exitosa
    socket.on('connect', (_) {
      reconnectAttempts = 0;
      onConnectionStatusChange(true);
      debugPrint('✅ Conectado al servidor');
    });

    // Evento cuando se pierde la conexión
    socket.on('disconnect', (_) {
      onConnectionStatusChange(false);
      debugPrint('❌ Desconectado');
    });

    // Evento cuando ocurre un error de conexión
    socket.on('connect_error', (error) {
      debugPrint('❌ Error de conexión: $error');
      onConnectionStatusChange(false);
      if (reconnectAttempts < maxReconnectAttempts) {
        reconnectAttempts++;
        final delay = _calculateDelay(reconnectAttempts);
        debugPrint(
          'Intentando reconectar en ${delay}ms... ($reconnectAttempts/$maxReconnectAttempts)',
        );
        Future.delayed(Duration(milliseconds: delay), reconnect);
      }
    });

    // Evento para manejar errores específicos del servidor
    socket.on('error', (error) {
      debugPrint('❌ Error del servidor: $error');
      // Opcional: Podrías notificar a la UI con un callback adicional
    });

    // Evento para recibir mensajes desde el servidor
    socket.on('message', (data) {
      if (data is Map &&
          data.containsKey('from') &&
          data.containsKey('message')) {
        final from = data['from'].toString();
        final message = data['message'].toString();
        onMessage(from, message);
      } else {
        debugPrint('❌ Mensaje inválido recibido: $data');
      }
    });

    socket.connect();
  }

  // Método para enviar un mensaje al servidor
  void sendMessage(String message) {
    if (socket.connected) {
      socket.emit('clientMessage', message);
      onMessage('yo', message);
    } else {
      debugPrint('⚠️ No se puede enviar mensaje: no conectado');
    }
  }

  // Método para intentar reconectar manualmente
  void reconnect() {
    if (reconnectAttempts < maxReconnectAttempts) {
      socket.connect();
    }
  }

  // Calcula el retraso para la reconexión con backoff exponencial
  int _calculateDelay(int attempt) {
    const baseDelay = 1000; // 1 segundo
    const maxDelay = 30000; // 30 segundos
    final delay = baseDelay * (1 << attempt); // Backoff exponencial
    return delay > maxDelay ? maxDelay : delay;
  }

  // Método para cerrar la conexión y liberar recursos
  void dispose() => socket.dispose();
}
