import 'package:flutter/material.dart'; // Importa las herramientas visuales de Flutter
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Permite usar variables de entorno desde .env
import 'package:socket_io_client/socket_io_client.dart'
    as socket_io; // Cliente Socket.IO para Flutter

// Clase que maneja la conexión y comunicación con el servidor WebSocket
class SocketService {
  late socket_io.Socket socket; // Instancia del socket
  final Function(String, String)
  onMessage; // Callback para manejar mensajes entrantes
  final Function(bool)
  onConnectionStatusChange; // Callback para manejar el cambio de estado de conexión
  int reconnectAttempts = 0; // Contador de intentos de reconexión
  static const int maxReconnectAttempts =
      5; // Máximo número de intentos permitidos

  // Constructor que recibe funciones para manejar mensajes y cambios de conexión
  SocketService({
    required this.onMessage,
    required this.onConnectionStatusChange,
  });

  // Método que inicializa la conexión con el servidor WebSocket
  void initialize() {
    final String serverUrl =
        dotenv.env['SOCKET_SERVER'] ??
        'http://localhost:3000'; // Obtiene la URL del servidor desde .env o usa valor por defecto

    socket = socket_io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'], // Usa WebSocket como método de transporte
      'autoConnect': false, // Evita la conexión automática
      'auth': {
        'token': 'tu-token-secreto',
      }, // Token de autenticación personalizado
    });

    // Evento cuando la conexión es exitosa
    socket.on('connect', (_) {
      reconnectAttempts = 0; // Reinicia contador de reconexiones
      onConnectionStatusChange(true); // Notifica que está conectado
      debugPrint('✅ Conectado al servidor'); // Imprime mensaje de confirmación
    });

    // Evento cuando se pierde la conexión
    socket.on('disconnect', (_) {
      onConnectionStatusChange(false); // Notifica que está desconectado
      debugPrint('❌ Desconectado'); // Imprime mensaje de desconexión
    });

    // Evento cuando ocurre un error de conexión
    socket.on('connect_error', (error) {
      debugPrint('❌ Error de conexión: $error'); // Muestra detalle del error
      onConnectionStatusChange(false); // Marca como desconectado

      // Si aún no ha excedido el máximo de intentos, intenta reconectar
      if (reconnectAttempts < maxReconnectAttempts) {
        reconnectAttempts++; // Aumenta el contador
        debugPrint(
          'Intentando reconectar... ($reconnectAttempts/$maxReconnectAttempts)',
        );
        Future.delayed(
          const Duration(seconds: 2),
          reconnect,
        ); // Espera 2 segundos y reintenta conexión
      }
    });

    // Evento para recibir mensajes desde el servidor
    socket.on('message', (data) {
      if (data is Map) {
        // Verifica que el dato recibido sea un mapa
        final from =
            data['from'] ??
            'desconocido'; // Obtiene remitente o valor por defecto
        final message =
            data['message'] ?? ''; // Obtiene mensaje o valor por defecto
        onMessage(
          from.toString(),
          message.toString(),
        ); // Llama al callback para manejar el mensaje
      }
    });

    socket.connect(); // Inicia la conexión manualmente
  }

  // Método para enviar un mensaje al servidor
  void sendMessage(String message) {
    if (socket.connected) {
      // Verifica que la conexión esté activa
      socket.emit('clientMessage', message); // Envía el mensaje al servidor
      onMessage(
        'yo',
        message,
      ); // También actualiza el chat local con el mensaje enviado
    }
  }

  // Método para intentar reconectar manualmente al servidor
  void reconnect() => socket.connect();

  // Método para cerrar la conexión y liberar recursos
  void dispose() => socket.dispose();
}
