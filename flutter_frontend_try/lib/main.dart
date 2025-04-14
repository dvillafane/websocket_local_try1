import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/price_screen.dart';

Future<void> main() async {
  // Agrega manejo de errores al cargar el archivo .env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Error al cargar las variables de entorno: $e');
    // Aquí podrías establecer valores por defecto o detener la aplicación
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket.IO Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const PriceScreen(),
    );
  }
}
