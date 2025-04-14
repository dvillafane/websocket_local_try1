import 'package:flutter/material.dart'; // Paquete principal para construir UI
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Para cargar variables de entorno
import 'package:provider/provider.dart'; // Gestión de estado con Provider
import 'screens/chat_screen.dart'; // Importa la pantalla principal de chat
import 'models/socket_data.dart'; // Importa el modelo de estado de Socket para manejar la lógica

// Función principal asíncrona para preparar la app antes de arrancar
Future<void> main() async {
  bool envLoaded =
      true; // Bandera para verificar si se cargó correctamente el .env

  try {
    // Intenta cargar las variables de entorno desde el archivo ".env"
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // En caso de error, muestra mensaje en consola y cambia bandera
    debugPrint('Error al cargar las variables de entorno: $e');
    envLoaded = false;
  }

  // Inicializa la app proporcionando el modelo SocketData a todo el árbol de widgets
  runApp(
    ChangeNotifierProvider(
      create: (_) => SocketData(), // Crea la instancia del gestor de estado
      child: MyApp(
        envLoaded: envLoaded,
      ), // Inyecta la bandera de configuración al widget principal
    ),
  );
}

// Widget principal de la aplicación que configura MaterialApp
class MyApp extends StatelessWidget {
  final bool envLoaded; // Indica si el archivo .env se cargó correctamente

  const MyApp({
    super.key,
    required this.envLoaded,
  }); // Constructor con parámetro requerido

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket.IO Demo', // Título de la aplicación
      debugShowCheckedModeBanner:
          false, // Oculta la cinta de "debug" en la esquina superior
      theme: ThemeData(
        useMaterial3: true, // Activa Material Design 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ), // Configura esquema de colores basado en un "seed"
      ),
      // Define la pantalla inicial dependiendo si el .env fue cargado correctamente
      home: envLoaded ? const ChatScreen() : const ErrorScreen(),
    );
  }
}

// Pantalla que se muestra si falla la carga del archivo .env
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({
    super.key,
  }); // Constructor constante para mejor rendimiento

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Error: No se pudo cargar la configuración', // Mensaje de error amigable para el usuario
          style: const TextStyle(
            fontSize: 18,
            color: Colors.red,
          ), // Estilo rojo para indicar error
        ),
      ),
    );
  }
}
