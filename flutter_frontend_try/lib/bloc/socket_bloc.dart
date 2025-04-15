// lib/bloc/socket_bloc.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../services/socket_service.dart';

// ----------------------
// Eventos del Bloc
// ----------------------

// Clase abstracta base para todos los eventos relacionados con el socket.
abstract class SocketEvent extends Equatable {
  const SocketEvent();

  @override
  List<Object?> get props => [];
}

// Evento que se dispara para inicializar la conexión del socket.
class SocketInitializeEvent extends SocketEvent {}

// Evento que indica que el socket se ha conectado correctamente.
class SocketConnectedEvent extends SocketEvent {}

// Evento que indica que el socket se ha desconectado.
class SocketDisconnectedEvent extends SocketEvent {}

// Evento que representa que se ha recibido un nuevo mensaje.
class SocketMessageReceivedEvent extends SocketEvent {
  final String from;
  final String message;

  const SocketMessageReceivedEvent({required this.from, required this.message});

  @override
  List<Object?> get props => [from, message];
}

// Evento que representa la intención de enviar un mensaje.
class SocketSendMessageEvent extends SocketEvent {
  final String message;

  const SocketSendMessageEvent({required this.message});

  @override
  List<Object?> get props => [message];
}

// Evento que notifica si se está intentando reconectar al servidor.
class SocketReconnectingEvent extends SocketEvent {
  final bool isReconnecting;

  const SocketReconnectingEvent({required this.isReconnecting});

  @override
  List<Object?> get props => [isReconnecting];
}

// ----------------------
// Estado del Bloc
// ----------------------

// Clase que representa el estado actual de la conexión y los mensajes.
class SocketState extends Equatable {
  final List<Map<String, String>> messages; // Lista de mensajes enviados y recibidos.
  final bool isConnected; // Indica si hay conexión activa.
  final bool isReconnecting; // Indica si se está intentando reconectar.

  const SocketState({
    required this.messages,
    required this.isConnected,
    required this.isReconnecting,
  });

  // Constructor de estado inicial.
  factory SocketState.initial() {
    return const SocketState(
      messages: [],
      isConnected: false,
      isReconnecting: false,
    );
  }

  // Crea una nueva instancia con cambios opcionales.
  SocketState copyWith({
    List<Map<String, String>>? messages,
    bool? isConnected,
    bool? isReconnecting,
  }) {
    return SocketState(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isReconnecting: isReconnecting ?? this.isReconnecting,
    );
  }

  @override
  List<Object?> get props => [messages, isConnected, isReconnecting];
}

// ----------------------
// Implementación del Bloc
// ----------------------

// Clase principal que maneja los eventos y estados del socket.
class SocketBloc extends Bloc<SocketEvent, SocketState> {
  late SocketService socketService; // Servicio que maneja la lógica de conexión.
  int maxMessages = 50; // Número máximo de mensajes que se almacenan en memoria.

  SocketBloc() : super(SocketState.initial()) {
    // Registra qué función se llama para cada tipo de evento.
    on<SocketInitializeEvent>(_onInitialize);
    on<SocketConnectedEvent>(
      (event, emit) => emit(state.copyWith(isConnected: true, isReconnecting: false)),
    );
    on<SocketDisconnectedEvent>(
      (event, emit) => emit(state.copyWith(isConnected: false)),
    );
    on<SocketMessageReceivedEvent>(_onMessageReceived);
    on<SocketSendMessageEvent>(_onSendMessage);
    on<SocketReconnectingEvent>(
      (event, emit) => emit(state.copyWith(isReconnecting: event.isReconnecting)),
    );
  }

  // Método que se ejecuta al recibir el evento de inicialización.
  Future<void> _onInitialize(
    SocketInitializeEvent event,
    Emitter<SocketState> emit,
  ) async {
    // Inicializa el servicio de socket con callbacks para mensajes y conexión.
    socketService = SocketService(
      onMessage: (from, message) {
        // Cuando llega un mensaje, dispara un evento para procesarlo.
        add(SocketMessageReceivedEvent(from: from, message: message));
      },
      onConnectionStatusChange: (status) {
        // Notifica al Bloc si se conecta o desconecta.
        if (status) {
          add(SocketConnectedEvent());
        } else {
          add(SocketDisconnectedEvent());
        }
      },
    );
    // Llama al método para conectar el socket.
    socketService.initialize();
  }

  // Maneja la lógica cuando se recibe un mensaje desde el socket.
  void _onMessageReceived(
    SocketMessageReceivedEvent event,
    Emitter<SocketState> emit,
  ) {
    // Crea una lista nueva basada en la lista actual de mensajes.
    final newMessages = List<Map<String, String>>.from(state.messages)
      ..add({'from': event.from, 'message': event.message});

    // Elimina el mensaje más antiguo si se supera el límite máximo.
    if (newMessages.length > maxMessages) {
      newMessages.removeAt(0);
    }
    // Actualiza el estado con la nueva lista de mensajes.
    emit(state.copyWith(messages: newMessages));
  }

  // Envía un mensaje al servidor o muestra un error si no está conectado.
  void _onSendMessage(SocketSendMessageEvent event, Emitter<SocketState> emit) {
    if (socketService.socket.connected) {
      // Si está conectado, se envía el mensaje.
      socketService.sendMessage(event.message);
      // No es necesario agregar manualmente el mensaje, el callback onMessage se encargará.
    } else {
      // Si no hay conexión, agrega un mensaje de advertencia al chat.
      final newMessages = List<Map<String, String>>.from(state.messages)..add({
        'from': 'system',
        'message': 'No se puede enviar mensaje: no conectado',
      });
      // Controla que no se exceda la cantidad máxima de mensajes.
      if (newMessages.length > maxMessages) {
        newMessages.removeAt(0);
      }
      // Actualiza el estado con el mensaje de error.
      emit(state.copyWith(messages: newMessages));
    }
  }

  @override
  // Método que se llama al cerrar el Bloc, limpia los recursos.
  Future<void> close() {
    socketService.dispose();
    return super.close();
  }
}
