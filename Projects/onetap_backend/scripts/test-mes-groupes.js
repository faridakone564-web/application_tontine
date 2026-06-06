require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const db = require('../config/db');

const sql =
  'SELECT DISTINCT g.id, g.nom, g.montant, g.frequence, g.is_active, g.max_membres, g.date_demarrage, ' +
  'b.nom AS beneficiary_nom, b.telephone AS beneficiary_telephone ' +
  'FROM `groups` g ' +
  'LEFT JOIN `beneficiaries` b ON g.id = b.group_id AND b.is_next = 1 ' +
  'LEFT JOIN group_members gm ON g.id = gm.group_id ' +
  'WHERE g.user_id = ? OR gm.user_id = ?';

db.query(sql, [1, 1])
  .then(([rows]) => {
    console.log('OK', rows.length, 'groupes');
    process.exit(0);
  })
  .catch((e) => {
    console.error('FAIL', e.message);
    process.exit(1);
  });
