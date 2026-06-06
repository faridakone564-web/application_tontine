require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const db = require('../config/db');

db.query('SHOW COLUMNS FROM `groups`')
  .then(([rows]) => {
    console.log(rows.map((c) => c.Field).join('\n'));
    process.exit(0);
  })
  .catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
