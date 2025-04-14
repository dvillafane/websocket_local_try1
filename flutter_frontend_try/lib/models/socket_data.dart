import 'package:flutter/material.dart'; // Importa el paquete principal de Flutter para UI y utilidades

// Clase que maneja el estado de las conexiones y mensajes del socket
class SocketData with ChangeNotifier {
  final List<Map<String, String>> _messages = []; // Lista privada para almacenar los mensajes recibidos
  bool _isConnected = false; // Estado de la conexión (conectado o no)
  bool _isReconnecting = false; // Estado de reconexión (en intento de reconectar o no)

  // Getter que expone la lista de mensajes
  List<Map<String, String>> get messages => _messages;

  // Getter que indica si el socket está conectado
  bool get isConnected => _isConnected;

  // Getter que indica si el socket está intentando reconectar
  bool get isReconnecting => _isReconnecting;

  // Método para agregar un nuevo mensaje a la lista
  void addMessage(String from, String message) {
    debugPrint('[$from]: $message'); // Imprime el mensaje en la consola para depuración
    _messages.add({'from': from, 'message': message}); // Añade el mensaje con su emisor
    if (_messages.length > 50) _messages.removeAt(0); // Limita la lista a máximo 50 mensajes, elimina el más antiguo si excede
    notifyListeners(); // Notifica a los widgets escuchando que hubo un cambio
  }

  // Método para actualizar el estado de conexión
  void setConnectionStatus(bool status) {
    _isConnected = status; // Actualiza el estado de conexión
    notifyListeners(); // Notifica a los widgets que escuchan el cambio
  }

  // Método para actualizar el estado de reconexión
  void setReconnecting(bool status) {
    _isReconnecting = status; // Actualiza el estado de reconexión
    notifyListeners(); // Notifica a los widgets que escuchan el cambio
  }
}
