const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const cron = require('node-cron');
require('dotenv').config();

const authMiddleware = require('./middleware/auth');
const dashboardController = require('./controllers/dashboardController');
const scheduledTaskController = require('./controllers/scheduledTaskController');

const app = express();

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'OneTap Tontine API fonctionne !' });
});

app.use('/api/auth', require('./routes/auth'));
app.use('/api/protected', require('./routes/protected'));
app.use('/api/yengapay', require('./routes/yengapay'));
app.use('/api/groups', require('./routes/groups'));
app.use('/api/users', require('./routes/users'));
app.use('/api/members', require('./routes/members'));
app.use('/api/beneficiaries', require('./routes/beneficiaries'));
app.use('/api/commissions', require('./routes/commissions'));
app.use('/api/payments', require('./routes/payments'));
app.use('/api/notifications', require('./routes/notifications'));
app.get('/api/payments/groupe/:groupId', authMiddleware, dashboardController.getGroupPayments);

const PORT = process.env.PORT || 3000;
const { DB_HOST, DB_USER, DB_PASSWORD, DB_NAME } = process.env;

async function initDatabase() {
  const connection = await mysql.createConnection({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASSWORD,
    multipleStatements: true,
  });

  await connection.query(`
    CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    USE \`${DB_NAME}\`;
    CREATE TABLE IF NOT EXISTS users (
      id INT AUTO_INCREMENT PRIMARY KEY,
      nom VARCHAR(100) NOT NULL,
      prenom VARCHAR(100) NOT NULL,
      telephone VARCHAR(20) NOT NULL UNIQUE,
      age INT NOT NULL DEFAULT 0,
      ville VARCHAR(100) DEFAULT '',
      quartier VARCHAR(100) DEFAULT '',
      numero_cnib VARCHAR(50) DEFAULT '',
      numero_urgence VARCHAR(20) DEFAULT '',
      nom_urgence VARCHAR(100) DEFAULT '',
      photo_profil VARCHAR(255) DEFAULT '',
      contrat_accepte BOOLEAN NOT NULL DEFAULT FALSE,
      pin VARCHAR(255) NOT NULL,
      score_reputation INT NOT NULL DEFAULT 100,
      paiements_a_temps INT NOT NULL DEFAULT 0,
      paiements_en_retard INT NOT NULL DEFAULT 0,
      tontines_terminees INT NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS \`groups\` (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      nom VARCHAR(100) NOT NULL,
      montant DECIMAL(10,2) NOT NULL DEFAULT 0,
      frequence VARCHAR(50) NOT NULL DEFAULT 'Hebdomadaire',
      max_membres INT NOT NULL DEFAULT 10,
      code_invitation VARCHAR(20) NOT NULL,
      is_active TINYINT(1) NOT NULL DEFAULT 1,
      status VARCHAR(50) NOT NULL DEFAULT 'recrutement',
      date_demarrage DATETIME NULL DEFAULT NULL,
      type ENUM('public','privé') NOT NULL DEFAULT 'privé',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS \`beneficiaries\` (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      nom VARCHAR(100) NOT NULL,
      telephone VARCHAR(20),
      is_next TINYINT(1) NOT NULL DEFAULT 0,
      ordre INT NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS group_members (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      user_id INT NOT NULL,
      statut ENUM('en_attente','approuvé','rejeté') NOT NULL DEFAULT 'en_attente',
      joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY unique_member (group_id, user_id)
    );
    CREATE TABLE IF NOT EXISTS \`payments\` (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      user_id INT NOT NULL,
      montant DECIMAL(10,2) NOT NULL,
      statut VARCHAR(50) NOT NULL DEFAULT 'PENDING',
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS commissions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      payment_id INT NOT NULL,
      group_id INT NOT NULL,
      createur_id INT NOT NULL,
      montant_total DECIMAL(12,2) NOT NULL,
      commission_plateforme DECIMAL(12,2) NOT NULL,
      commission_createur DECIMAL(12,2) NOT NULL,
      montant_net DECIMAL(12,2) NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (payment_id) REFERENCES payments(id),
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id),
      FOREIGN KEY (createur_id) REFERENCES users(id)
    );
    CREATE TABLE IF NOT EXISTS notifications (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      titre VARCHAR(255) NOT NULL,
      message TEXT NOT NULL,
      type VARCHAR(50) NOT NULL DEFAULT 'info',
      lu TINYINT(1) NOT NULL DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS payment_reminders (
      id INT AUTO_INCREMENT PRIMARY KEY,
      user_id INT NOT NULL,
      group_id INT NOT NULL,
      due_date DATE NOT NULL,
      sent_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE
    );
  `);

  // Ensure columns exist immediately after table creation
  try {
    await connection.query("ALTER TABLE `groups` ADD COLUMN max_membres INT NOT NULL DEFAULT 10 AFTER frequence");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding max_membres column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE `groups` ADD COLUMN type ENUM('public','privé') NOT NULL DEFAULT 'privé' AFTER max_membres");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding type column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE `groups` ADD COLUMN code_invitation VARCHAR(20) NOT NULL DEFAULT '' AFTER type");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding code_invitation column:', error.message);
    }
  }

  try {
    await connection.query(
      "ALTER TABLE `groups` ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'recrutement' AFTER is_active"
    );
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding status column:', error.message);
    }
  }

  try {
    await connection.query("UPDATE `groups` SET status = 'recrutement' WHERE status IS NULL OR status = ''");
  } catch (error) {
    console.warn('Warning setting default group status:', error.message);
  }

  try {
    await connection.query("UPDATE `groups` SET status = 'recrutement' WHERE status = 'en_attente'");
  } catch (error) {
    console.warn('Warning updating old group status values:', error.message);
  }

  try {
    await connection.query("UPDATE `groups` SET status = 'terminée' WHERE status = 'terminee'");
  } catch (error) {
    console.warn('Warning updating old group status values:', error.message);
  }

  try {
    await connection.query("ALTER TABLE `groups` MODIFY COLUMN status VARCHAR(50) NOT NULL DEFAULT 'recrutement' AFTER is_active");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning updating status column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE `groups` ADD COLUMN date_demarrage DATETIME NULL DEFAULT NULL AFTER status");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding date_demarrage column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE `groups` ADD COLUMN places_restantes INT NOT NULL DEFAULT 0 AFTER date_demarrage");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding places_restantes column:', error.message);
    }
  }

  try {
    await connection.query(
      "ALTER TABLE group_members ADD COLUMN statut ENUM('en_attente','approuvé','rejeté') NOT NULL DEFAULT 'en_attente' AFTER user_id"
    );
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding statut to group_members:', error.message);
    }
  }

  try {
    await connection.query(`
      UPDATE \`groups\` g
      LEFT JOIN (
        SELECT group_id, COUNT(*) AS member_count
        FROM group_members
        WHERE statut IS NULL OR statut <> 'rejeté'
        GROUP BY group_id
      ) mc ON mc.group_id = g.id
      SET g.places_restantes = GREATEST(g.max_membres - COALESCE(mc.member_count, 0), 0)
    `);
  } catch (error) {
    console.warn('Warning recalculating places_restantes:', error.message);
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN prenom VARCHAR(100) NOT NULL AFTER nom");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding prenom column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN age INT NOT NULL DEFAULT 0 AFTER telephone");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding age column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN ville VARCHAR(100) DEFAULT '' AFTER age");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding ville column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN quartier VARCHAR(100) DEFAULT '' AFTER ville");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding quartier column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN numero_cnib VARCHAR(50) DEFAULT '' AFTER quartier");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding numero_cnib column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN numero_urgence VARCHAR(20) DEFAULT '' AFTER numero_cnib");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding numero_urgence column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN nom_urgence VARCHAR(100) DEFAULT '' AFTER numero_urgence");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding nom_urgence column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN photo_profil VARCHAR(255) DEFAULT '' AFTER nom_urgence");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding photo_profil column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN contrat_accepte BOOLEAN NOT NULL DEFAULT FALSE AFTER photo_profil");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding contrat_accepte column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN score_reputation INT NOT NULL DEFAULT 100 AFTER pin");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding score_reputation column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN paiements_a_temps INT NOT NULL DEFAULT 0 AFTER score_reputation");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding paiements_a_temps column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN paiements_en_retard INT NOT NULL DEFAULT 0 AFTER paiements_a_temps");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding paiements_en_retard column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE users ADD COLUMN tontines_terminees INT NOT NULL DEFAULT 0 AFTER paiements_en_retard");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding tontines_terminees column:', error.message);
    }
  }

  try {
    await connection.query("ALTER TABLE beneficiaries ADD COLUMN ordre INT NOT NULL DEFAULT 0 AFTER is_next");
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding ordre column to beneficiaries:', error.message);
    }
  }

  console.log(`Base de données ${DB_NAME} initialisée avec succès`);
  await connection.end();
}

initDatabase()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`Serveur démarré sur le port ${PORT}`);
    });

    // Planifier la vérification des paiements non payés à minuit chaque jour
    cron.schedule('0 0 * * *', () => {
      console.log('⏰ Exécution de la vérification des paiements à minuit...');
      scheduledTaskController.checkUnpaidPayments();
    });

    console.log('⏰ Tâche planifiée: Vérification des paiements à minuit chaque jour');
  })
  .catch((error) => {
    console.error('Erreur de connexion à la base de données :', error.message);
    process.exit(1);
  });