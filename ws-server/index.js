/**
 * Servidor WebSocket para mensajes bidireccionales entre clientes y consola.
 * Con cluster, entrada de consola centralizada y mejoras en seguridad y rendimiento.
 */

// Carga las variables de entorno desde un archivo .env
require('dotenv').config();

// Importa las librerías necesarias
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const sanitize = require('sanitize-html');
const winston = require('winston');
const cluster = require('cluster');
const os = require('os');
const readline = require('readline');
const jwt = require('jsonwebtoken');

// Número de CPUs disponibles para crear un worker por cada una
const numCPUs = os.cpus().length;

// Configura el logger con formato y destinos (archivo y consola)
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'server.log' }),
    new winston.transports.Console(),
  ],
});

// Define el puerto a usar (desde .env o 3000 por defecto)
const PORT = process.env.PORT || 3000;

// Clave secreta para JWT (debe estar en variables de entorno en producción)
const JWT_SECRET = process.env.JWT_SECRET || 'default-secret';

// Si este proceso es el maestro...
if (cluster.isMaster) {
  logger.info(`Maestro ${process.pid} iniciado`);

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
    input: process.stdin,
    output: process.stdout,
  });

  // Cada vez que se ingresa una línea en consola
  rl.on('line', (input) => {
    const trimmedInput = input.trim();
    if (trimmedInput !== '') {
      if (trimmedInput === 'shutdown') {
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
        : ['http://localhost:3000'],
      methods: ['GET', 'POST'],
    },
  });

  // Mapa para rastrear timestamps de mensajes por cliente
  const messageRateLimit = new Map();

  // Middleware de autenticación de clientes usando JWT
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        socket.user = decoded;
        next();
      } catch (err) {
        logger.warn('Token inválido', { socketId: socket.id });
        next(new Error('Token inválido'));
      }
    } else {
      logger.warn('Token no proporcionado', { socketId: socket.id });
      next(new Error('Token no proporcionado'));
    }
  });

  // Manejo de la conexión WebSocket
  io.on('connection', (socket) => {
    const socketId = socket.id;
    messageRateLimit.set(socketId, []); // Inicializa array de timestamps

    logger.info('Nuevo cliente conectado', { socketId });

    // Cuando se recibe un mensaje del cliente
    socket.on('clientMessage', (message) => {
      const now = Date.now();
      const timestamps = messageRateLimit.get(socketId);

      // Filtra timestamps del último segundo (Punto 4: Límite de mensajes)
      const recentTimestamps = timestamps.filter((t) => now - t < 1000);
      if (recentTimestamps.length >= 5) {
        logger.warn('Límite de tasa excedido', { socketId });
        socket.emit('error', 'Límite de mensajes excedido: máximo 5 mensajes por segundo');
        return;
      }

      // Agrega el nuevo timestamp
      recentTimestamps.push(now);
      messageRateLimit.set(socketId, recentTimestamps);

      // Validación del mensaje (Punto 3: Manejo de errores)
      if (typeof message === 'string' && message.trim().length <= 200) {
        const cleanMessage = sanitize(message.trim(), { allowedTags: [], allowedAttributes: {} });
        logger.info('Mensaje del cliente recibido', { message: cleanMessage });
        socket.broadcast.emit('message', { from: 'client', message: cleanMessage });
      } else {
        logger.warn('Mensaje inválido', { socketId });
        socket.emit('error', 'Mensaje inválido: debe ser un string no vacío y menor a 200 caracteres');
      }
    });

    // Manejo de la desconexión del cliente
    socket.on('disconnect', () => {
      logger.info('Cliente desconectado', { socketId });
      messageRateLimit.delete(socketId); // Limpia al desconectar
    });

    // Manejo de errores específicos del socket (Punto 3: Manejo de errores)
    socket.on('error', (error) => {
      logger.error('Error en el socket', { socketId, error });
    });
  });

  // Escucha mensajes enviados desde el proceso maestro
  process.on('message', (data) => {
    if (data) {
      if (data.shutdown) {
        io.emit('message', { from: 'server', message: data.message });
        io.close(() => {
          logger.info('Conexiones WebSocket cerradas');
          server.close(() => {
            logger.info('Servidor HTTP cerrado');
            process.exit(0);
          });
        });
      } else if (data.from && data.message) {
        io.emit('message', data);
      }
    }
  });

  // Manejo global de errores que no fueron capturados (Punto 3: Manejo de errores)
  process.on('uncaughtException', (error) => {
    logger.error('Error no capturado:', { error });
  });

  process.on('unhandledRejection', (reason) => {
    logger.error('Promesa rechazada:', { reason });
  });

  // Inicia el servidor HTTP escuchando en el puerto configurado
  server.listen(PORT, () => {
    logger.info(`Worker ${process.pid} corriendo en http://localhost:${PORT}`);
  });
}
