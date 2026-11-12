'use strict';
const os = require('node:os');
const express = require('express');
const helmet = require('helmet');
const { getInstanceMetadata } = require('./metadata');
const db = require('./db');

const escapeHtml = (value) =>
  String(value).replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function createApp() {
  const app = express();
  const startedAt = Date.now();
  const version = process.env.APP_VERSION || 'dev';

  app.disable('x-powered-by');
  app.use(helmet());

  // Utilisé par l'ALB : doit rester indépendant de la base de données, sinon
  // une coupure RDS ferait retirer TOUTES les instances du load balancer.
  app.get('/health', (_req, res) => {
    res.status(200).json({ status: 'ok' });
  });

  async function info() {
    const meta = await getInstanceMetadata();
    return {
      app: 'cloud-native-devops-showcase',
      version,
      hostname: os.hostname(),
      instanceId: meta.instanceId,
      availabilityZone: meta.availabilityZone,
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
    };
  }

  app.get('/api/info', async (_req, res) => {
    res.json(await info());
  });

  app.get('/api/db', async (_req, res) => {
    try {
      await db.ping();
      res.json({ database: 'up' });
    } catch (err) {
      console.error('db check failed:', err.message);
      res.status(503).json({
        database: db.isConfigured() ? 'down' : 'not-configured',
      });
    }
  });

  app.get('/', async (_req, res) => {
    const i = await info();
    res.type('html').send(`<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Cloud-Native DevOps Showcase</title>
<style>
  body{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;display:grid;place-items:center;min-height:100vh;margin:0}
  main{background:#1e293b;padding:2rem 2.5rem;border-radius:12px;max-width:560px;width:90%}
  h1{margin-top:0;font-size:1.4rem} dt{color:#94a3b8;font-size:.8rem;margin-top:1rem}
  dd{margin:0;font-size:1.1rem;font-family:ui-monospace,monospace} .ok{color:#4ade80}
</style></head><body><main>
<h1>Cloud-Native DevOps Showcase</h1>
<p class="ok">&#9679; Application en ligne</p>
<dl>
<dt>Instance EC2</dt><dd>${escapeHtml(i.instanceId)}</dd>
<dt>Zone de disponibilité</dt><dd>${escapeHtml(i.availabilityZone)}</dd>
<dt>Version (commit)</dt><dd>${escapeHtml(i.version.slice(0, 12))}</dd>
<dt>Uptime</dt><dd>${i.uptimeSeconds}s</dd>
</dl>
<p><small>Rafraîchissez la page : l'ALB répartit la charge entre les AZ.</small></p>
</main></body></html>`);
  });

  return app;
}

module.exports = { createApp };
