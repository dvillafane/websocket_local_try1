// Carga las variables de entorno para configuración
require('dotenv').config();

const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const readline = require('readline');

// Crea una aplicación Express
const app = express();
// Crea un servidor HTTP
const server = http.createServer(app);
// Inicializa Socket.IO con el servidor HTTP
const io = socketIo(server);

// Puerto configurable mediante variable de entorno (o 3000 por defecto)
const PORT = process.env.PORT || 3000;

// Sirve archivos estáticos si fuera necesario (opcional)
app.use(express.static('public'));

// Intervalo global para emitir actualizaciones a todos los clientes
const globalInterval = setInterval(() => {
  // Genera un precio aleatorio y formatea el timestamp en ISO
  const priceUpdate = {
    symbol: 'BTC',
    price: (30000 + Math.random() * 5000).toFixed(2),
    // Utiliza ISO para el formato del timestamp
    timestamp: new Date().toISOString()
  };
  // Emite a todos los clientes conectados
  io.emit('priceUpdate', priceUpdate);
  //console.log(`Actualización emitida: ${JSON.stringify(priceUpdate)}`);
}, 2000);

// Evento cuando un cliente se conecta
io.on('connection', (socket) => {
  console.log('Nuevo cliente conectado');

  // Maneja la desconexión del cliente
  socket.on('disconnect', () => {
    console.log('Cliente desconectado');
  });

  // Manejo adicional de errores del socket en cada conexión
  socket.on('error', (error) => {
    console.error('Error en el socket:', error);
  });
});

// Configura la interfaz para leer desde la consola
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Escucha cada línea escrita en la consola
rl.on('line', (input) => {
  // Validación básica para evitar enviar líneas vacías y comandos especiales
  if (input.trim() !== '') {
    // Por ejemplo, podrías agregar comandos especiales aquí
    if (input.trim() === 'shutdown') {
      console.log('Cerrando el servidor...');
      clearInterval(globalInterval); // Cancela el intervalo global
      io.emit('messageFromServer', 'El servidor se está cerrando');
      process.exit(); // O una manera segura de cerrar el servidor
    }
    // Envía el mensaje a todos los clientes conectados
    io.emit('messageFromServer', input);
  }
});

// Configura el servidor para que escuche en el puerto configurado
server.listen(PORT, () => {
  console.log(`Servidor WebSocket corriendo en http://localhost:${PORT}`);
  console.log('Escribe un mensaje y presiona enter para enviar a los clientes:');
});
