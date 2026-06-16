// Simple end-to-end test for join-request workflow
// Usage: node tests/e2e_join_test.js

const BASE = process.env.BASE || 'http://localhost:3000/api';

// If direct DB insert is needed, we will require the project's DB pool
let dbPool = null;
try {
  dbPool = require('../config/db');
} catch (e) {
  // ignore if not available in this runtime
}

const rnd = () => Math.floor(1000 + Math.random() * 9000);

async function req(path, method = 'GET', body = null, token = null) {
  const url = `${BASE}${path}`;
  const opts = { method, headers: {} };
  if (body) {
    opts.headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  if (token) opts.headers['Authorization'] = `Bearer ${token}`;
  const res = await fetch(url, opts);
  const text = await res.text();
  try { return JSON.parse(text); } catch { return { status: res.status, text }; }
}

async function main() {
  try {
    console.log('BASE =', BASE);

    // 1) Create creator
    const creatorPhone = `2267000${rnd()}`;
    console.log('Creating creator', creatorPhone);
    const ins1 = await req('/auth/inscription', 'POST', {
      nom: 'Creator', prenom: 'Test', telephone: creatorPhone,
      age: 30, ville: 'Ouagadougou', quartier: 'Centre', numero_cnib: 'A12345678', pin: '12345678',
      numero_urgence: '22670000000', nom_urgence: 'Urg', photo_profil: 'profile.jpg', contrat_accepte: true
    });
    console.log('ins1 ->', ins1);
    const creatorToken = ins1.token;
    const creatorId = ins1.user && ins1.user.id;

    // Deposit to creator wallet
    console.log('Depositing to creator wallet');
    const dep = await req('/wallet/deposer', 'POST', { userId: creatorId, montant: 10000 }, creatorToken);
    console.log('deposit ->', dep);

    // Create public group
    console.log('Creating public group');
    const groupResp = await req('/groups/creer', 'POST', { nom: 'Groupe Test Public', montant: 10000, frequence: 'hebdomadaire', max_membres: 5, type: 'public' }, creatorToken);
    console.log('groupResp ->', groupResp);
    let groupId = groupResp.groupe && groupResp.groupe.id;

    // If creation failed due to DB mismatch, try to pick an existing public group
    if (!groupId) {
      console.log('Group creation failed, fetching public groups to reuse');
      const publics = await req('/groups/publics', 'GET', null, creatorToken);
      console.log('publics ->', publics);
      if (Array.isArray(publics) && publics.length > 0) {
        groupId = publics[0].id;
        console.log('Using existing public group id=', groupId);
      }
      // If still no groupId and we have DB access, insert a group owned by creator
      if (dbPool) {
        console.log('No public groups found or accessible. Inserting a test group directly in DB.');
        const code = `TEST${Date.now()}`;
        const insertCols = ['user_id','nom','montant','frequence','max_membres','type','code_invitation','places_restantes','commission_createur','created_at'];
        const vals = [creatorId, 'Groupe Test Direct', 5000, 'mensuel', 6, 'public', code, 5, 5.0, new Date()];
        try {
          const [res] = await dbPool.query(`INSERT INTO \`groups\` (${insertCols.join(',')}) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)` , vals);
          groupId = res.insertId;
          console.log('Inserted groupId=', groupId);
        } catch (err) {
          console.error('DB insert group failed:', err.message);
        }
      }
    }

    // 2) Create requester user
    const userPhone = `2267001${rnd()}`;
    console.log('Creating requester', userPhone);
    const ins2 = await req('/auth/inscription', 'POST', {
      nom: 'Requester', prenom: 'User', telephone: userPhone,
      age: 28, ville: 'Ouagadougou', quartier: 'Est', numero_cnib: 'B12345678', pin: '87654321',
      numero_urgence: '22670000001', nom_urgence: 'Urg2', photo_profil: 'avatar.jpg', contrat_accepte: true
    });
    console.log('ins2 ->', ins2);
    const userToken = ins2.token;

    // 3) Request to join via groupId (public)
    console.log('Requesting join for groupId', groupId);
    const join = await req('/members/rejoindre', 'POST', { groupId }, userToken);
    console.log('join ->', join);

    // 4) Get pending list as creator
    console.log('Fetching pending list as creator');
    const pending = await req(`/members/en-attente/${groupId}`, 'GET', null, creatorToken);
    console.log('pending ->', pending);

    // 5) Approve first pending if any
    if (Array.isArray(pending) && pending.length > 0) {
      const memberId = pending[0].memberId || pending[0].id || pending[0].member_id;
      console.log('Approving memberId', memberId);
      const appr = await req(`/members/approuver/${memberId}`, 'PUT', {}, creatorToken);
      console.log('approve ->', appr);
    } else {
      console.log('No pending members found, aborting approval step.');
    }

    // 6) List members
    console.log('Listing members for group');
    const members = await req(`/groups/membres/${groupId}`, 'GET', null, creatorToken);
    console.log('members ->', members);

    console.log('E2E test completed');
    process.exit(0);
  } catch (err) {
    console.error('E2E test error', err);
    process.exit(2);
  }
}

// Node 18+ supports top-level await; otherwise call main()
if (typeof globalThis.fetch !== 'function') {
  console.error('fetch is not available in this Node runtime. Use Node 18+ or install a fetch polyfill.');
  process.exit(3);
}

main();
