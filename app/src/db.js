'use strict';
// Accès PostgreSQL (RDS). Le mot de passe n'est JAMAIS passé en variable
// d'environnement : il est lu à l'exécution dans AWS Secrets Manager grâce au
// rôle IAM de l'instance (secret géré par RDS : manage_master_user_password).

const { Pool } = require('pg');
const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require('@aws-sdk/client-secrets-manager');

let poolPromise = null;

function isConfigured() {
  return Boolean(process.env.DB_HOST);
}

async function loadCredentials() {
  if (process.env.DB_SECRET_ARN) {
    const client = new SecretsManagerClient({ region: process.env.AWS_REGION });
    const out = await client.send(
      new GetSecretValueCommand({ SecretId: process.env.DB_SECRET_ARN }),
    );
    const secret = JSON.parse(out.SecretString);
    return { user: secret.username, password: secret.password };
  }
  return { user: process.env.DB_USER, password: process.env.DB_PASSWORD };
}

function getPool() {
  if (!isConfigured()) {
    return Promise.reject(new Error('database not configured'));
  }
  if (!poolPromise) {
    poolPromise = loadCredentials().then((creds) => {
      const pool = new Pool({
        host: process.env.DB_HOST,
        port: Number(process.env.DB_PORT || 5432),
        database: process.env.DB_NAME || 'appdb',
        ...creds,
        // RDS PostgreSQL 15+ impose TLS. Amélioration possible : embarquer le
        // bundle CA RDS et activer rejectUnauthorized.
        ssl: process.env.DB_SSL === 'false' ? false : { rejectUnauthorized: false },
        max: 5,
        connectionTimeoutMillis: 3000,
        idleTimeoutMillis: 30000,
      });
      pool.on('error', (err) => console.error('pg pool error:', err.message));
      return pool;
    });
    poolPromise.catch(() => {
      poolPromise = null;
    });
  }
  return poolPromise;
}

async function ping() {
  try {
    const pool = await getPool();
    const { rows } = await pool.query('SELECT 1 AS ok');
    return rows[0];
  } catch (err) {
    // 28P01 = échec d'authentification : le secret a pu être renouvelé
    // (rotation automatique) -> on recrée le pool avec le nouveau secret.
    if (err.code === '28P01') poolPromise = null;
    throw err;
  }
}

module.exports = { ping, isConfigured };
