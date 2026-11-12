'use strict';
const { createApp } = require('./app');

const port = Number(process.env.PORT || 8080);
const server = createApp().listen(port, '0.0.0.0', () => {
  console.log(`Application démarrée sur le port ${port}`);
});

// L'ALB garde les connexions ouvertes 60 s : le serveur Node doit les garder
// plus longtemps pour éviter des erreurs 502 sporadiques.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;

// Arrêt propre : l'ASG / Docker envoient SIGTERM lors d'un remplacement.
function shutdown(signal) {
  console.log(`${signal} reçu, arrêt en cours...`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10_000).unref();
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
