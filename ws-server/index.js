/**
 * Servidor WebSocket para mensajes bidireccionales entre clientes y consola.
 * Con cluster y entrada de consola centralizada en el proceso maestro
 */

// Carga las variables de entorno desde un archivo .env
require('dotenv').config();

// Importa las librerías necesarias
const express = require('express'); // Framework para servidor web
const http = require('http'); // Módulo nativo para crear servidor HTTP
const socketIo = require('socket.io'); // Biblioteca para comunicación WebSocket
const sanitize = require('sanitize-html'); // Para limpiar el HTML en los mensajes
const rateLimit = require('express-rate-limit'); // Middleware para limitar peticiones
const winston = require('winston'); // Librería para logging
const cluster = require('cluster'); // Permite crear procesos hijos
const os = require('os'); // Para obtener información del sistema

// Número de CPUs disponibles para crear un worker por cada una
const numCPUs = os.cpus().length;

// Librería para entrada de consola interactiva
const readline = require('readline');

// Configura el logger con formato y destinos (archivo y consola)
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(), // Agrega la fecha y hora a cada log
    winston.format.json()        // Formatea los mensajes en JSON
  ),
  transports: [
    new winston.transports.File({ filename: 'server.log' }), // Guarda logs en un archivo
    new winston.transports.Console(), // También imprime en consola
  ],
});

// Define el puerto a usar (desde .env o 3000 por defecto)
const PORT = process.env.PORT || 3000;

// Si este proceso es el maestro...
if (cluster.isMaster) {
  logger.info(`Maestro ${process.pid} iniciado`); // Notifica el inicio del proceso maestro

  // Crea un worker por cada CPU disponible
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  // Cuando un worker se termina, se informa y se crea uno nuevo
  cluster.on('exit', (worker) => {
    logger.warn(`Worker ${worker.process.pid} muerto`);
    cluster.fork();
  });

  // Configura la entrada de consola centralizada en el proceso maestro
  const rl = readline.createInterface({
    input: process.stdin,   // Entrada de consola
    output: process.stdout, // Salida de consola
  });

  // Cada vez que se ingresa una línea en consola
  rl.on('line', (input) => {
    const trimmedInput = input.trim();
    if (trimmedInput !== '') {
      if (trimmedInput === 'shutdown') { // Comando para apagar el servidor
        // Enviar mensaje de apagado a todos los workers
        for (const id in cluster.workers) {
          cluster.workers[id].send({
            shutdown: true,
            message: 'El servidor se está cerrando',
          });
        }
        rl.close();
        process.exit(0);
        return;
      }
      // Enviar el mensaje ingresado a todos los workers
      for (const id in cluster.workers) {
        cluster.workers[id].send({ from: 'server', message: trimmedInput });
      }
      logger.info('Mensaje enviado desde consola', { message: trimmedInput });
    }
  });
} else {
  // -----------------
  // Código del worker (proceso secundario que ejecuta el servidor WebSocket)
  // -----------------

  // Crea una aplicación de Express
  const app = express();

  // Crea un servidor HTTP basándose en la aplicación Express
  const server = http.createServer(app);

  // Configura el servidor Socket.IO para habilitar el WebSocket
  const io = socketIo(server, {
    cors: {
      origin: process.env.ALLOWED_ORIGINS
        ? process.env.ALLOWED_ORIGINS.split(',')
        : ['http://localhost:3000'], // Orígenes permitidos para CORS
      methods: ['GET', 'POST'], // Métodos HTTP permitidos
    },
  });

  // Configura el rate limiting para evitar abusos
  const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // Periodo de 15 minutos
    max: 100, // Máximo 100 conexiones por IP en ese periodo
    message: 'Demasiadas conexiones, intenta de nuevo más tarde.',
  });
  app.use(limiter);

  // Sirve archivos estáticos de la carpeta 'public'
  app.use(express.static('public'));

  // Middleware de autenticación de clientes usando token
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (token && token === process.env.CLIENT_TOKEN) {
      next();
    } else {
      logger.warn('Autenticación fallida', { socketId: socket.id });
      next(new Error('Autenticación fallida'));
    }
  });

  // Manejo de la conexión WebSocket
  io.on('connection', (socket) => {
    logger.info('Nuevo cliente conectado', { socketId: socket.id });

    // Cuando se recibe un mensaje del cliente
    socket.on('clientMessage', (message) => {
      // Verifica que el mensaje sea un string, no sea vacío y tenga longitud adecuada
      if (typeof message === 'string' && message.trim().length <= 200) {
        // Limpia el mensaje para evitar etiquetas HTML y atributos no deseados
        const cleanMessage = sanitize(message.trim(), { allowedTags: [], allowedAttributes: {} });
        logger.info('Mensaje del cliente recibido', { message: cleanMessage });
        // Envía el mensaje a todos menos al cliente emisor
        socket.broadcast.emit('message', { from: 'client', message: cleanMessage });
      } else {
        logger.warn('Mensaje del cliente inválido', { socketId: socket.id });
      }
    });

    // Manejo de la desconexión del cliente
    socket.on('disconnect', () => {
      logger.info('Cliente desconectado', { socketId: socket.id });
    });

    // Manejo de errores específicos del socket
    socket.on('error', (error) => {
      logger.error('Error en el socket', { socketId: socket.id, error });
    });
  });

  // Escucha mensajes enviados desde el proceso maestro (por ejemplo, para apagar el servidor)
  process.on('message', (data) => {
    if (data) {
      if (data.shutdown) {
        // Emite el mensaje de shutdown a todos los clientes conectados
        io.emit('message', { from: 'server', message: data.message });
        io.close(() => {
          logger.info('Conexiones WebSocket cerradas');
          server.close(() => {
            logger.info('Servidor HTTP cerrado');
            process.exit(0);
          });
        });
      } else if (data.from && data.message) {
        // Envía mensajes enviados desde la consola del maestro a los clientes
        io.emit('message', data);
      }
    }
  });

  // Manejo global de errores que no fueron capturados
  process.on('uncaughtException', (error) => {
    logger.error('Error no capturado:', { error });
  });

  // Manejo de promesas rechazadas sin captura
  process.on('unhandledRejection', (reason) => {
    logger.error('Promesa rechazada:', { reason });
  });

  // Inicia el servidor HTTP escuchando en el puerto configurado
  server.listen(PORT, () => {
    logger.info(`Worker ${process.pid} corriendo en http://localhost:${PORT}`);
  });
}
