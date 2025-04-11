import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

class PriceScreen extends StatefulWidget {
  const PriceScreen({super.key});

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  late socket_io.Socket socket;
  Map<String, dynamic>? priceData;

  @override
  void initState() {
    super.initState();

    final String serverUrl = dotenv.env['SOCKET_SERVER']!;
    socket = socket_io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.on('connect', (_) => debugPrint('✅ Conectado al servidor'));
    socket.on('disconnect', (_) => debugPrint('❌ Desconectado'));
    socket.on('priceUpdate', (data) {
      debugPrint('📈 Actualización recibida: $data');
      setState(() {
        priceData = Map<String, dynamic>.from(data);
      });
    });
  }

  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualización de Precio en Tiempo Real'),
      ),
      body: Center(
        child: priceData == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Criptomoneda: ${priceData!['symbol']}',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Precio: \$${priceData!['price']}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text('Actualizado en: ${priceData!['timestamp']}'),
                ],
              ),
      ),
    );
  }
}
