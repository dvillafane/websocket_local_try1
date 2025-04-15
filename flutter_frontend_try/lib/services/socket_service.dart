import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:http/http.dart' as http;
import 'dart:convert';

class SocketService {
  // Instancia del socket que se conectará al servidor.
  late socket_io.Socket socket;

  // Función de callback para manejar mensajes recibidos.
  final Function(String, String) onMessage;

  // Función de callback para notificar cambios en el estado de conexión.
  final Function(bool) onConnectionStatusChange;

  // Contador de intentos de reconexión.
  int reconnectAttempts = 0;

  // Número máximo de intentos de reconexión permitidos.
  static const int maxReconnectAttempts = 5;

  SocketService({
    required this.onMessage,
    required this.onConnectionStatusChange,
  });

  // Realiza una petición HTTP POST para obtener un token de autenticación.
  Future<String> authenticate() async {
    final response = await http.post(
      Uri.parse('${dotenv.env['SOCKET_SERVER'] ?? 'http://localhost:3000'}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'test', 'password': '1234'}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['token'];
    } else {
      throw Exception('Fallo en la autenticación');
    }
  }

  // Inicializa la conexión al servidor de sockets.
  Future<void> initialize() async {
    // Obtiene la URL del servidor desde variables de entorno o usa localhost como valor por defecto.
    final String serverUrl = dotenv.env['SOCKET_SERVER'] ?? 'http://localhost:3000';
    try {
      // Autentica al cliente antes de conectar al socket.
      final token = await authenticate();

      // Configura la conexión socket con autenticación y transporte WebSocket.
      socket = socket_io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'auth': {'token': token},
      });

      // Evento que se dispara al conectar exitosamente al servidor.
      socket.on('connect', (_) {
        reconnectAttempts = 0;
        onConnectionStatusChange(true);
        debugPrint('✅ Conectado al servidor');
      });

      // Evento que se dispara cuando se pierde la conexión.
      socket.on('disconnect', (_) {
        onConnectionStatusChange(false);
        debugPrint('❌ Desconectado');
      });

      // Evento que se dispara cuando ocurre un error de conexión.
      socket.on('connect_error', (error) {
        debugPrint('❌ Error de conexión: $error');
        onConnectionStatusChange(false);

        // Si el número de intentos de reconexión no supera el máximo permitido, reintenta conectar.
        if (reconnectAttempts < maxReconnectAttempts) {
          reconnectAttempts++;
          final delay = _calculateDelay(reconnectAttempts);
          debugPrint(
            'Intentando reconectar en ${delay}ms... ($reconnectAttempts/$maxReconnectAttempts)',
          );
          // Espera un tiempo antes de intentar reconectar.
          Future.delayed(Duration(milliseconds: delay), reconnect);
        } else {
          // Informa que no se pudo reconectar tras varios intentos.
          onMessage('system', 'No se pudo reconectar tras $maxReconnectAttempts intentos');
        }
      });

      // Evento que maneja errores recibidos desde el servidor.
      socket.on('error', (error) {
        debugPrint('❌ Error del servidor: $error');
        onMessage('system', 'Error: $error');
      });

      // Evento que se ejecuta cuando se recibe un mensaje del servidor.
      socket.on('message', (data) {
        if (data is Map && data.containsKey('from') && data.containsKey('message')) {
          final from = data['from'].toString();
          final message = data['message'].toString();
          onMessage(from, message);
        } else {
          debugPrint('❌ Mensaje inválido recibido: $data');
        }
      });

      // Inicia la conexión con el servidor después de configurar todos los eventos.
      socket.connect();

    } catch (e) {
      debugPrint('Error al inicializar socket: $e');
      onMessage('system', 'Error de autenticación o conexión');
    }
  }

  // Envía un mensaje al servidor si la conexión está activa.
  void sendMessage(String message) {
    if (socket.connected) {
      socket.emit('clientMessage', message);
      onMessage('yo', message);
    } else {
      debugPrint('⚠️ No se puede enviar mensaje: no conectado');
      onMessage('system', 'No se puede enviar mensaje: no conectado');
    }
  }

  // Reintenta conectar si no se han agotado los intentos máximos.
  void reconnect() {
    if (reconnectAttempts < maxReconnectAttempts) {
      socket.connect();
    }
  }

  // Calcula el tiempo de espera antes de reintentar la conexión (backoff exponencial).
  int _calculateDelay(int attempt) {
    const baseDelay = 1000; // Tiempo base en milisegundos.
    const maxDelay = 30000; // Tiempo máximo permitido en milisegundos.
    final delay = baseDelay * (1 << attempt);
    return delay > maxDelay ? maxDelay : delay;
  }

  // Libera recursos y cierra la conexión cuando ya no se necesita.
  void dispose() => socket.dispose();
}
