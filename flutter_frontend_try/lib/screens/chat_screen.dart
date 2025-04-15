// lib/screens/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/socket_bloc.dart';

// Pantalla principal del chat, donde se mostrará la conversación.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Referencia al BLoC que maneja la lógica de conexión y mensajes.
  late SocketBloc socketBloc;

  // Controlador para manejar el texto del input de mensajes.
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Obtiene una instancia del SocketBloc desde el contexto.
    socketBloc = BlocProvider.of<SocketBloc>(context);
    // Dispara el evento para inicializar la conexión de socket.
    socketBloc.add(SocketInitializeEvent());
  }

  @override
  void dispose() {
    // Libera los recursos que usa el controlador de texto.
    _messageController.dispose();
    super.dispose();
  }

  // Widget que construye una burbuja de mensaje dependiendo del remitente.
  Widget _buildMessageBubble(Map<String, String> msg) {
    // Extrae el remitente y el contenido del mensaje.
    final sender = msg['from'] ?? 'desconocido';
    final message = msg['message'] ?? '';

    // Variables para definir el color y alineación de la burbuja.
    Color bubbleColor;
    CrossAxisAlignment alignment;

    // Condición para personalizar la burbuja si el mensaje es del usuario.
    if (sender == 'yo') {
      bubbleColor = Colors.blue[200]!;
      alignment = CrossAxisAlignment.end;
    }
    // Si el mensaje proviene del servidor.
    else if (sender.toLowerCase().contains('server') ||
        sender.toLowerCase().contains('servidor')) {
      bubbleColor = Colors.deepPurple[200]!;
      alignment = CrossAxisAlignment.start;
    }
    // Si el mensaje proviene del sistema.
    else if (sender == 'system') {
      bubbleColor = Colors.red[200]!;
      alignment = CrossAxisAlignment.center;
    }
    // Caso general para otros remitentes.
    else {
      bubbleColor = Colors.grey[300]!;
      alignment = CrossAxisAlignment.start;
    }

    // Estructura visual de la burbuja.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Muestra el nombre del remitente.
          Text(
            sender == 'yo' ? 'Tú' : sender,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          // Contenedor del mensaje con estilo de burbuja.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(sender == 'yo' ? 16 : 0),
                bottomRight: Radius.circular(sender == 'yo' ? 0 : 16),
              ),
            ),
            child: Text(message, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // BlocConsumer escucha los estados del SocketBloc y reconstruye la UI.
    return BlocConsumer<SocketBloc, SocketState>(
      listener: (context, state) {
        // Si se pierde la conexión y no está intentando reconectar, muestra un aviso.
        if (!state.isConnected && !state.isReconnecting) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Desconectado del servidor')),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            // Cambia el título del AppBar según el estado de la conexión.
            title: Text(
              state.isConnected
                  ? 'Chat Activo'
                  : state.isReconnecting
                      ? 'Reconectando...'
                      : 'Desconectado',
            ),
            // Muestra un ícono diferente según el estado de la conexión.
            leading: Icon(
              state.isConnected
                  ? Icons.wifi
                  : state.isReconnecting
                      ? Icons.sync
                      : Icons.wifi_off,
              color: state.isConnected ? Colors.green : Colors.red,
            ),
          ),
          body: Column(
            children: [
              // Lista de mensajes ocupando todo el espacio disponible.
              Expanded(
                child: state.messages.isEmpty
                    // Si no hay mensajes, muestra un texto.
                    ? const Center(child: Text('Aún no hay mensajes...'))
                    // Si hay mensajes, los muestra en una lista invertida (últimos abajo).
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        reverse: true,  // El mensaje más reciente aparece al final.
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          // Invierte el índice para mostrar los mensajes en orden.
                          final reversedIndex = state.messages.length - 1 - index;
                          return _buildMessageBubble(state.messages[reversedIndex]);
                        },
                      ),
              ),
              const Divider(height: 1),  // Línea divisoria sobre la caja de texto.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    // Campo de texto para escribir nuevos mensajes.
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje...',
                          border: OutlineInputBorder(),
                        ),
                        // Al presionar "Enter" envía el mensaje si no está vacío.
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            socketBloc.add(SocketSendMessageEvent(
                                message: value.trim()));
                            _messageController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),  // Espacio entre el input y el botón.
                    // Botón de envío de mensaje.
                    IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.blue,
                      // Solo se puede enviar si hay conexión.
                      onPressed: state.isConnected
                          ? () {
                              final text = _messageController.text.trim();
                              if (text.isNotEmpty) {
                                socketBloc.add(SocketSendMessageEvent(
                                    message: text));
                                _messageController.clear();
                              }
                            }
                          : null,  // Si no hay conexión, el botón queda desactivado.
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
