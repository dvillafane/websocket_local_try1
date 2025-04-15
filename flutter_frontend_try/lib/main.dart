import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/chat_screen.dart';
import 'bloc/socket_bloc.dart';

// La función principal donde inicia la ejecución de la app.
Future<void> main() async {
  bool envLoaded =
      true; // Variable que indica si las variables de entorno se cargaron correctamente.

  try {
    // Intenta cargar las variables de entorno desde el archivo .env.
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // Si ocurre un error al cargar el archivo .env, imprime el error en la consola.
    debugPrint('Error al cargar las variables de entorno: $e');
    envLoaded = false; // Marca como false si hubo un fallo.
  }

  // Inicia la aplicación con un proveedor BLoC que inyecta el SocketBloc a toda la app.
  runApp(
    BlocProvider(
      create: (_) => SocketBloc(), // Crea una instancia de SocketBloc.
      child: MyApp(
        envLoaded: envLoaded,
      ), // Pasa si las variables de entorno se cargaron correctamente.
    ),
  );
}

// Clase principal de la aplicación que define la configuración visual.
class MyApp extends StatelessWidget {
  final bool envLoaded; // Propiedad que indica si el .env se cargó con éxito.
  const MyApp({super.key, required this.envLoaded}); // Constructor de la clase.

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Socket.IO Demo', // Título de la app.
      debugShowCheckedModeBanner:
          false, // Oculta la etiqueta de debug en la esquina.
      theme: ThemeData(
        useMaterial3: true, // Activa el estilo visual de Material 3.
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ), // Define un esquema de colores basado en un color semilla.
      ),
      // Si las variables de entorno se cargaron, muestra la pantalla de chat; si no, muestra la pantalla de error.
      home: envLoaded ? const ChatScreen() : const ErrorScreen(),
    );
  }
}

// Pantalla que se muestra cuando no se pudo cargar la configuración (.env).
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Error: No se pudo cargar la configuración', // Mensaje de error visible para el usuario.
          style: const TextStyle(
            fontSize: 18,
            color: Colors.red,
          ), // Estilo de texto en rojo para destacar el error.
        ),
      ),
    );
  }
}
