const express = require('express');
const http = require('http');
const socketIo = require('socket.io');

// Crea una aplicación Express
const app = express();
// Crea un servidor HTTP
const server = http.createServer(app);
// Inicializa Socket.IO con el servidor HTTP
const io = socketIo(server);

// Sirve archivos estáticos si fuera necesario (opcional)
app.use(express.static('public'));

// Evento cuando un cliente se conecta
io.on('connection', (socket) => {
  console.log('Nuevo cliente conectado');

  // Simula el envío de datos cada 2 segundos (por ejemplo, precios de criptomonedas)
  const intervalId = setInterval(() => {
    // Genera un precio aleatorio
    const priceUpdate = {
      symbol: 'BTC',
      price: (30000 + Math.random() * 5000).toFixed(2),
      timestamp: new Date()
    };
    // Envía la actualización al cliente
    socket.emit('priceUpdate', priceUpdate);
  }, 2000);

  // Maneja la desconexión del cliente
  socket.on('disconnect', () => {
    console.log('Cliente desconectado');
    clearInterval(intervalId);
  });
});

// Configura el servidor para que escuche en el puerto 3000
const PORT = 3000;
server.listen(PORT, () => {
  console.log(`Servidor WebSocket corriendo en http://localhost:${PORT}`);
});
