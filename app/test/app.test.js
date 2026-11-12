'use strict';
process.env.IMDS_DISABLED = 'true';

const test = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { createApp } = require('../src/app');

let server;
let base;

test.before(async () => {
  server = createApp().listen(0, '127.0.0.1');
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
});

test.after(() => server.close());

test('GET /health renvoie 200', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
});

test('GET /api/info expose instance et version', async () => {
  const res = await fetch(`${base}/api/info`);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.app, 'cloud-native-devops-showcase');
  assert.ok('instanceId' in body && 'availabilityZone' in body);
});

test('GET /api/db renvoie 503 sans base configurée', async () => {
  const res = await fetch(`${base}/api/db`);
  assert.equal(res.status, 503);
  assert.deepEqual(await res.json(), { database: 'not-configured' });
});

test('GET / renvoie la page HTML', async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /Cloud-Native DevOps Showcase/);
});
