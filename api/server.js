// Microservicio "Shipment API" — TP3 Arquitectura de Sistemas (GlobalLogistics S.A.)
// Responde con el hostname del contenedor para poder ver qué réplica atendió cada petición.
const express = require('express');
const os = require('os');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;
const HOSTNAME = process.env.INSTANCE_ID || os.hostname(); // En Docker = ID corto del contenedor
const STARTED_AT = new Date().toISOString();

// Endpoint principal: devuelve el ID de la instancia que respondió
app.get('/', (req, res) => {
  // Respuesta de largo fijo: Apache Benchmark marca como "Failed" las respuestas
  // cuyo tamaño cambia entre peticiones.
  res.json({
    servicio: 'globallogistics-shipment-api',
    hostname: HOSTNAME,
    timestamp: new Date().toISOString(),
  });
});

// Health check: lo usan Docker (healthcheck) y NGINX (reintento ante fallas)
app.get('/health', (req, res) => {
  res.json({ status: 'UP', hostname: HOSTNAME, iniciadoEn: STARTED_AT, uptimeSeg: Math.round(process.uptime()) });
});

// Endpoint opcional de carga de CPU: simula un cálculo pesado (p. ej. cotizar un envío)
// para llevar las réplicas a la saturación de CPU en el escenario extremo.
app.get('/cotizar', (req, res) => {
  const iteraciones = Math.min(parseInt(req.query.n, 10) || 20000, 500000);
  let hash = 'envio';
  for (let i = 0; i < iteraciones; i++) {
    hash = crypto.createHash('sha256').update(hash).digest('hex');
  }
  res.json({ hostname: HOSTNAME, iteraciones, resultado: hash.slice(0, 16) });
});

const server = app.listen(PORT, () => {
  console.log(`[${HOSTNAME}] API escuchando en el puerto ${PORT}`);
});

// Apagado prolijo cuando Docker detiene el contenedor
process.on('SIGTERM', () => server.close(() => process.exit(0)));
