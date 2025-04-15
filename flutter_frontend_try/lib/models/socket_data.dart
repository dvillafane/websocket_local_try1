import 'package:flutter/material.dart';

// Clase que maneja datos recibidos por un socket y notifica a los widgets cuando hay cambios.
class SocketData with ChangeNotifier {
  // Lista privada que almacena los mensajes recibidos.
  final List<Map<String, String>> _messages = [];

  // Variable privada que indica si la conexión está activa.
  bool _isConnected = false;

  // Variable privada que indica si se está intentando reconectar.
  bool _isReconnecting = false;

  // Getter para acceder a la lista de mensajes desde fuera de la clase.
  List<Map<String, String>> get messages => _messages;

  // Getter para saber si la conexión está activa.
  bool get isConnected => _isConnected;

  // Getter para saber si el socket está intentando reconectar.
  bool get isReconnecting => _isReconnecting;

  // Método para agregar un nuevo mensaje a la lista.
  void addMessage(String from, String message) {
    // Imprime en la consola quién envió el mensaje y el contenido.
    debugPrint('[$from]: $message');

    // Agrega el nuevo mensaje a la lista.
    _messages.add({'from': from, 'message': message});

    // Si hay más de 50 mensajes, elimina el más antiguo.
    if (_messages.length > 50) _messages.removeAt(0);

    // Notifica a los widgets que escuchan que hubo un cambio en los datos.
    notifyListeners();
  }

  // Método para actualizar el estado de la conexión.
  void setConnectionStatus(bool status) {
    _isConnected = status;
    // Notifica a los widgets que hubo un cambio.
    notifyListeners();
  }

  // Método para actualizar el estado de reconexión.
  void setReconnecting(bool status) {
    _isReconnecting = status;
    // Notifica a los widgets que hubo un cambio.
    notifyListeners();
  }

  // Método que simula la carga de mensajes antiguos.
  void loadMoreMessages() {
    // Inserta un mensaje falso al principio de la lista.
    _messages.insert(0, {'from': 'server', 'message': 'Mensaje antiguo'});

    // Notifica a los widgets que hubo un cambio en la lista.
    notifyListeners();
  }
}
