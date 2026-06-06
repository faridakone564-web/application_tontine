require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const http = require('http');

const base = 'http://127.0.0.1:3000';

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const req = http.request(
      `${base}${path}`,
      {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
          ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
        },
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => (raw += c));
        res.on('end', () => {
          let parsed;
          try {
            parsed = raw ? JSON.parse(raw) : null;
          } catch {
            parsed = raw;
          }
          resolve({ status: res.statusCode, body: parsed });
        });
      }
    );
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

(async () => {
  const phone = process.argv[2];
  const pin = process.argv[3];
  if (!phone || !pin) {
    console.log('Usage: node scripts/test-api.js <telephone> <pin>');
    process.exit(1);
  }

  const health = await request('GET', '/');
  console.log('GET /', health.status, health.body);

  const login = await request('POST', '/api/auth/connexion', { telephone: phone, pin });
  console.log('POST connexion', login.status, login.body);
  if (!login.body?.token) process.exit(1);

  const userId = login.body.user?.id;
  const token = login.body.token;

  const groupes = await request('GET', `/api/groups/mes-groupes/${userId}`, null, token);
  console.log('GET mes-groupes', groupes.status, JSON.stringify(groupes.body, null, 2));

  const total = await request('GET', `/api/payments/total/${userId}`, null, token);
  console.log('GET total', total.status, total.body);
})().catch((e) => {
  console.error('FAIL:', e.message);
  process.exit(1);
});
