'use strict';
// Lecture des métadonnées de l'instance EC2 via IMDSv2 (jeton obligatoire).
// Permet à la page d'accueil d'afficher l'instance et l'AZ qui répondent :
// idéal pour visualiser le load balancing et la haute disponibilité en démo.

const IMDS = 'http://169.254.169.254/latest';
let cached = null;

async function request(url, options = {}, timeoutMs = 1000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    if (!res.ok) throw new Error(`IMDS HTTP ${res.status}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

async function getInstanceMetadata() {
  if (cached) return cached;

  if (process.env.IMDS_DISABLED === 'true') {
    cached = { instanceId: 'local', availabilityZone: 'local' };
    return cached;
  }

  try {
    const token = await request(`${IMDS}/api/token`, {
      method: 'PUT',
      headers: { 'X-aws-ec2-metadata-token-ttl-seconds': '300' },
    });
    const headers = { 'X-aws-ec2-metadata-token': token };
    const [instanceId, availabilityZone] = await Promise.all([
      request(`${IMDS}/meta-data/instance-id`, { headers }),
      request(`${IMDS}/meta-data/placement/availability-zone`, { headers }),
    ]);
    cached = { instanceId, availabilityZone };
  } catch {
    cached = { instanceId: 'unknown', availabilityZone: 'unknown' };
  }
  return cached;
}

module.exports = { getInstanceMetadata };
