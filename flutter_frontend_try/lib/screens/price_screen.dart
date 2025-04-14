import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

// Servicio para manejar la conexión del socket
class SocketService {
  late socket_io.Socket socket;
  final Function(Map<String, dynamic>) onPriceUpdate;
  final Function(String) onServerMessage;
  final Function(bool) onConnectionStatusChange;

  SocketService({
    required this.onPriceUpdate,
    required this.onServerMessage,
    required this.onConnectionStatusChange,
  });

  void initialize() {
    final String serverUrl = dotenv.env['SOCKET_SERVER']!;
    socket = socket_io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.on('connect', (_) {
      onConnectionStatusChange(true);
      debugPrint('✅ Conectado al servidor');
    });

    socket.on('disconnect', (_) {
      onConnectionStatusChange(false);
      debugPrint('❌ Desconectado');
    });

    socket.on('connect_error', (error) {
      debugPrint('❌ Error de conexión: $error');
      onConnectionStatusChange(false);
    });

    socket.on('priceUpdate', (data) {
      debugPrint('📈 Actualización recibida: $data');
      onPriceUpdate(Map<String, dynamic>.from(data));
    });

    socket.on('messageFromServer', (data) {
      debugPrint('💬 Mensaje del servidor: $data');
      onServerMessage(data.toString());
    });
  }

  void reconnect() {
    socket.connect();
  }

  void dispose() {
    socket.dispose();
  }
}

// Define un StatefulWidget llamado PriceScreen
class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

// Define el estado asociado al widget PriceScreen
class _PriceScreenState extends State<PriceScreen> {
  // Variable para almacenar los datos del precio recibidos
  Map<String, dynamic>? priceData;
  // Variable para almacenar mensajes simples enviados desde el servidor
  String? serverMessage;
  // Bandera para indicar el estado de conexión
  bool isConnected = false;

  // Instancia del servicio de conexión
  late SocketService socketService;

  @override
  void initState() {
    super.initState();
    socketService = SocketService(
      onPriceUpdate: (data) {
        if (!mounted) return;
        setState(() {
          priceData = data;
        });
      },
      onServerMessage: (message) {
        if (!mounted) return;
        setState(() {
          serverMessage = message;
        });
      },
      onConnectionStatusChange: (status) {
        if (!mounted) return;
        setState(() {
          isConnected = status;
        });
      },
    );
    // Inicializa la conexión del socket al iniciar el widget
    socketService.initialize();
  }

  @override
  void dispose() {
    // Libera los recursos del socket antes de destruir el widget
    socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Título de la aplicación en la barra superior
        title: const Text('Actualización de Precio en Tiempo Real'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Muestra el estado de la conexión con un ícono y texto
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Conectado' : 'Desconectado',
                  style: TextStyle(
                    color: isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botón para reconectar si la conexión se ha perdido
            ElevatedButton(
              onPressed:
                  isConnected
                      ? null
                      : () {
                        // Intento de reconexión manual mediante el servicio
                        socketService.reconnect();
                      },
              child: const Text('Reconectar'),
            ),
            const SizedBox(height: 20),

            // Muestra los datos del precio si están disponibles, o un indicador de carga
            priceData == null
                ? const CircularProgressIndicator()
                : Column(
                  children: [
                    Text(
                      'Criptomoneda: ${priceData?['symbol'] ?? 'Desconocido'}',
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Precio: \$${priceData?['price'] ?? 'N/A'}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Actualizado en: ${priceData?['timestamp'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
            const SizedBox(height: 40),

            // Sección para mostrar mensajes enviados desde el servidor
            const Text(
              'Mensaje desde el servidor:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              serverMessage ?? 'Esperando mensaje...',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
