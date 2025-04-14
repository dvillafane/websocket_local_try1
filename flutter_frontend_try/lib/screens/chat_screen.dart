import 'package:flutter/material.dart'; // Importa las herramientas de UI de Flutter
import 'package:provider/provider.dart'; // Importa Provider para gestión de estado
import '../models/socket_data.dart'; // Importa el modelo que maneja datos del socket
import '../services/socket_service.dart'; // Importa el servicio que maneja la conexión socket

// Widget principal que representa la pantalla del chat
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

// Estado de la pantalla de chat
class _ChatScreenState extends State<ChatScreen> {
  late SocketService
  socketService; // Instancia de SocketService para manejar la conexión
  final TextEditingController _messageController =
      TextEditingController(); // Controlador para el campo de texto

  @override
  void initState() {
    super.initState();
    final socketData = Provider.of<SocketData>(
      context,
      listen: false,
    ); // Obtiene la instancia de SocketData sin escuchar cambios
    socketService = SocketService(
      onMessage: (from, message) {
        socketData.addMessage(
          from,
          message,
        ); // Añade mensaje recibido al modelo
      },
      onConnectionStatusChange: (status) {
        socketData.setConnectionStatus(
          status,
        ); // Actualiza estado de conexión en el modelo
        if (!status) {
          socketData.setReconnecting(
            false,
          ); // Si pierde conexión, desactiva reconexión automática
        }
      },
    );
    socketService.initialize(); // Inicializa la conexión socket
  }

  @override
  void dispose() {
    socketService.dispose(); // Libera recursos de la conexión socket
    _messageController.dispose(); // Libera recursos del controlador de texto
    super.dispose();
  }

  // Método que construye el widget de cada burbuja de mensaje
  Widget _buildMessageBubble(Map<String, String> msg) {
    final sender = msg['from'] ?? 'desconocido'; // Obtiene el remitente
    final message = msg['message'] ?? ''; // Obtiene el contenido del mensaje

    Color bubbleColor; // Color de la burbuja
    CrossAxisAlignment alignment; // Alineación de la burbuja

    // Configura estilo según el remitente
    if (sender == 'yo') {
      bubbleColor =
          Colors.blue[200]!; // Color para mensajes enviados por el usuario
      alignment = CrossAxisAlignment.end; // Alinea a la derecha
    } else if (sender.toLowerCase().contains('server') ||
        sender.toLowerCase().contains('servidor')) {
      bubbleColor = Colors.deepPurple[200]!; // Color para mensajes del servidor
      alignment = CrossAxisAlignment.start; // Alinea a la izquierda
    } else {
      bubbleColor = Colors.grey[300]!; // Color para otros remitentes
      alignment = CrossAxisAlignment.start; // Alinea a la izquierda
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 8,
      ), // Margen alrededor de cada burbuja
      child: Column(
        crossAxisAlignment: alignment, // Alineación de burbuja
        children: [
          Text(
            sender == 'yo'
                ? 'Tú'
                : sender, // Muestra 'Tú' si el remitente es el usuario
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ), // Estilo del nombre del remitente
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ), // Espaciado interno de la burbuja
            decoration: BoxDecoration(
              color: bubbleColor, // Aplica el color definido según el remitente
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(sender == 'yo' ? 16 : 0),
                bottomRight: Radius.circular(sender == 'yo' ? 0 : 16),
              ), // Bordes redondeados personalizados según quién envió el mensaje
            ),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16),
            ), // Muestra el texto del mensaje
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocketData>(
      builder:
          (context, socketData, child) => Scaffold(
            appBar: AppBar(
              title: Text(
                socketData.isConnected
                    ? 'Chat Activo' // Texto cuando la conexión está activa
                    : socketData.isReconnecting
                    ? 'Reconectando...' // Texto cuando intenta reconectar
                    : 'Desconectado', // Texto cuando está desconectado
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child:
                      socketData.messages.isEmpty
                          ? const Center(
                            child: Text('Aún no hay mensajes...'),
                          ) // Mensaje cuando no hay mensajes
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ), // Espacio alrededor de la lista
                            reverse:
                                true, // Muestra los mensajes más nuevos abajo
                            itemCount:
                                socketData
                                    .messages
                                    .length, // Número de mensajes
                            itemBuilder: (context, index) {
                              final reversedIndex =
                                  socketData.messages.length -
                                  1 -
                                  index; // Invierte el orden de la lista
                              return _buildMessageBubble(
                                socketData.messages[reversedIndex],
                              ); // Construye cada burbuja
                            },
                          ),
                ),
                const Divider(height: 1), // Línea divisoria sobre el input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ), // Espaciado alrededor de la fila de entrada
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              _messageController, // Controlador que gestiona el texto ingresado
                          decoration: const InputDecoration(
                            hintText:
                                'Escribe un mensaje...', // Texto de sugerencia
                            border:
                                OutlineInputBorder(), // Borde del campo de texto
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              // Verifica que el texto no esté vacío
                              socketService.sendMessage(
                                value.trim(),
                              ); // Envía el mensaje
                              _messageController
                                  .clear(); // Limpia el campo de texto
                            }
                          },
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ), // Espacio entre el campo de texto y el botón
                      IconButton(
                        icon: const Icon(Icons.send), // Icono de enviar
                        color: Colors.blue, // Color del botón
                        onPressed:
                            socketData.isConnected
                                ? () {
                                  final text =
                                      _messageController.text
                                          .trim(); // Obtiene el texto ingresado
                                  if (text.isNotEmpty) {
                                    // Verifica que no sea vacío
                                    socketService.sendMessage(
                                      text,
                                    ); // Envía el mensaje
                                    _messageController
                                        .clear(); // Limpia el campo
                                  }
                                }
                                : null, // Desactiva el botón si no hay conexión
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
