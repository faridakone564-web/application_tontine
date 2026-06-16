const db = require('../config/db');

// Calculate creation fee based on contribution amount
function calculerFraisCreation(montant) {
  const amount = Number(montant);
  if (Number.isNaN(amount) || amount <= 0) {
    return 2000;
  }

  if (amount <= 20000) return 2000;
  if (amount <= 50000) return 3000;
  if (amount <= 100000) return 5000;
  if (amount <= 200000) return 7500;
  if (amount <= 300000) return 10000;
  if (amount <= 500000) return 15000;
  if (amount <= 700000) return 20000;
  return 25000;
}

function generateInvitationCode() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

async function ensureGroupMembersTable() {
  await db.query(`
    CREATE TABLE IF NOT EXISTS group_members (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      user_id INT NOT NULL,
      statut ENUM('en_attente','approuvé','rejeté') NOT NULL DEFAULT 'en_attente',
      request_type ENUM('code','public') NOT NULL DEFAULT 'code',
      invitation_code VARCHAR(20) DEFAULT NULL,
      joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY unique_member (group_id, user_id)
    )
  `);
  try {
    await db.query(
      "ALTER TABLE group_members ADD COLUMN request_type ENUM('code','public') NOT NULL DEFAULT 'code' AFTER statut"
    );
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding request_type to group_members:', error.message);
    }
  }

  try {
    await db.query(
      "ALTER TABLE group_members ADD COLUMN invitation_code VARCHAR(20) DEFAULT NULL AFTER request_type"
    );
  } catch (error) {
    if (!error.message.includes('Duplicate column') && !error.message.includes('déjà utilisé')) {
      console.warn('Warning adding invitation_code to group_members:', error.message);
    }
  }}

async function refreshGroupPlacesRestantes(groupId) {
  const [rows] = await db.query(
    'SELECT COUNT(*) AS count FROM group_members WHERE group_id = ? AND statut != ?',
    [groupId, 'rejeté']
  );
  const currentCount = rows[0]?.count || 0;
  await db.query(
    'UPDATE `groups` SET places_restantes = GREATEST(max_membres - ?, 0) WHERE id = ?',
    [currentCount, groupId]
  );
}

async function buildBeneficiaryOrder(groupId) {
  const [approvedMembers] = await db.query(
    `SELECT gm.user_id, u.nom, u.telephone
     FROM group_members gm
     JOIN users u ON gm.user_id = u.id
     WHERE gm.group_id = ? AND gm.statut = 'approuvé'
     ORDER BY gm.joined_at ASC`,
    [groupId]
  );

  await db.query('DELETE FROM beneficiaries WHERE group_id = ?', [groupId]);

  let ordre = 0;
  for (const member of approvedMembers) {
    ordre += 1;
    await db.query(
      'INSERT INTO beneficiaries (group_id, user_id, nom, telephone, ordre, is_next) VALUES (?, ?, ?, ?, ?, ?)',
      [groupId, member.user_id, member.nom, member.telephone, ordre, ordre === 1 ? 1 : 0]
    );
  }

  return ordre;
}

// Créer un nouveau groupe
exports.creerGroupe = async (req, res) => {
  try {
    const { nom, montant, frequence, max_membres, type } = req.body;
    const userId = req.user.userId;

    if (!nom || !montant || !frequence || !max_membres) {
      return res.status(400).json({ message: 'Tous les champs sont requis' });
    }

    const frequencesValides = ['quotidien', 'hebdomadaire', 'quinzaine', 'mensuel'];
    if (!frequencesValides.includes(frequence.toLowerCase())) {
      return res.status(400).json({ message: 'Fréquence invalide. Valeurs acceptées: quotidien, hebdomadaire, quinzaine, mensuel' });
    }

    const typesValides = ['public', 'privé'];
    const groupeType = typesValides.includes((type || '').toLowerCase()) ? type.toLowerCase() : 'privé';

    const maxMembres = parseInt(max_membres, 10);
    if (Number.isNaN(maxMembres) || maxMembres < 2) {
      return res.status(400).json({ message: 'Le nombre maximum de membres est invalide' });
    }

    const montantNumber = Number(montant);
    if (Number.isNaN(montantNumber) || montantNumber <= 0) {
      return res.status(400).json({ message: 'Montant invalide pour la tontine' });
    }

    const fraisCreation = calculerFraisCreation(montantNumber);
    const commission = 5.0; // Fixed organizer commission rate

    // Check if user has paid creation fee
    const [userWallet] = await db.query('SELECT * FROM wallets WHERE user_id = ?', [userId]);
    if (!userWallet || userWallet.length === 0) {
      return res.status(400).json({ 
        message: 'Wallet non trouvé. Veuillez payer les frais de création.',
        fraisCreation: fraisCreation,
        requiresPayment: true
      });
    }

    const userSolde = parseFloat(userWallet[0].solde);
    if (userSolde < fraisCreation) {
      return res.status(400).json({ 
        message: `Solde insuffisant. Frais de création: ${fraisCreation} FCFA. Votre solde: ${userSolde} FCFA.`,
        fraisCreation: fraisCreation,
        soldeActuel: userSolde,
        requiresPayment: true
      });
    }

    // Deduct creation fee from user wallet
    const nouveauSolde = userSolde - fraisCreation;
    await db.query(
      'UPDATE wallets SET solde = ?, total_retire = total_retire + ? WHERE user_id = ?',
      [nouveauSolde, fraisCreation, userId]
    );

    // Add transaction record
    await db.query(
      'INSERT INTO wallet_transactions (user_id, group_id, type, montant, solde_avant, solde_apres, description) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, 0, 'frais_creation', fraisCreation, userSolde, nouveauSolde, 'Frais de création de groupe']
    );

    // Credit creation fee to OneTap platform wallet
    const PLATFORM_USER_ID = 0;
    const [platformWallet] = await db.query('SELECT * FROM wallets WHERE user_id = ?', [PLATFORM_USER_ID]);
    const platformSoldeActuel = platformWallet.length > 0 ? parseFloat(platformWallet[0].solde) : 0.0;
    
    if (!platformWallet || platformWallet.length === 0) {
      await db.query(
        'INSERT INTO wallets (user_id, solde, total_depose, total_retire) VALUES (?, 0.00, 0.00, 0.00)',
        [PLATFORM_USER_ID]
      );
    }

    const platformNouveauSolde = platformSoldeActuel + fraisCreation;
    await db.query(
      'UPDATE wallets SET solde = ?, total_depose = total_depose + ? WHERE user_id = ?',
      [platformNouveauSolde, fraisCreation, PLATFORM_USER_ID]
    );

    await db.query(
      'INSERT INTO wallet_transactions (user_id, group_id, type, montant, solde_avant, solde_apres, description) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [PLATFORM_USER_ID, 0, 'reception_frais_creation', fraisCreation, platformSoldeActuel, platformNouveauSolde, 'Réception frais de création']
    );

    let codeInvitation;
    let codeExists;
    do {
      codeInvitation = generateInvitationCode();
      const [existing] = await db.query('SELECT id FROM `groups` WHERE code_invitation = ?', [codeInvitation]);
      codeExists = existing.length > 0;
    } while (codeExists);

    const [result] = await db.query(
      'INSERT INTO `groups` (user_id, nom, montant, frequence, max_membres, frais_creation, type, code_invitation, places_restantes, commission_createur) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, nom, montant, frequence, max_membres, fraisCreation, groupeType, codeInvitation, Math.max(max_membres - 1, 0), commission]
    );

    // Record transaction for platform
    await db.query(
      'INSERT INTO wallet_transactions (user_id, group_id, type, montant, solde_avant, solde_apres, description) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [PLATFORM_USER_ID, result.insertId, 'depot_manuel', fraisCreation, platformSoldeActuel, platformNouveauSolde, `Frais de création du groupe: ${nom} (OneTap)`]
    );

    await ensureGroupMembersTable();
    await db.query('INSERT INTO group_members (group_id, user_id, statut) VALUES (?, ?, ?)', [result.insertId, userId, 'approuvé']);

    // Add creator to beneficiaries with ordre = 1
    const [user] = await db.query('SELECT nom, telephone FROM users WHERE id = ?', [userId]);
    if (user.length > 0) {
      await db.query(
        'INSERT INTO beneficiaries (group_id, user_id, nom, telephone, ordre, is_next) VALUES (?, ?, ?, ?, ?, ?)',
        [result.insertId, userId, user[0].nom, user[0].telephone, 1, 1]
      );
    }

    res.status(201).json({
      message: 'Groupe créé avec succès',
      groupe: {
        id: result.insertId,
        nom,
        montant,
        frequence,
        max_membres,
        type: groupeType,
        code_invitation: codeInvitation,
      },
    });
  } catch (error) {
    console.error('Erreur création groupe:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// Calculate creation fees endpoint
exports.calculerFraisCreationEndpoint = async (req, res) => {
  try {
    const montant = Number(req.params.montant);
    if (Number.isNaN(montant) || montant <= 0) {
      return res.status(400).json({ message: 'Montant de cotisation invalide' });
    }

    const fraisCreation = calculerFraisCreation(montant);
    res.json({
      montant: montant,
      fraisCreation: fraisCreation,
      message: `Pour une cotisation de ${montant} FCFA, les frais de création sont de ${fraisCreation} FCFA.`
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur lors du calcul des frais' });
  }
};

// Note: join requests are handled centrally by `controllers/membersController.js`.
// The deprecated route `POST /api/groups/rejoindre` already returns 410 in routes/groups.js.

exports.demarrerGroupe = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT user_id, status, max_membres FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    if (groupRows[0].user_id !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    if (groupRows[0].status !== 'recrutement') {
      return res.status(400).json({ message: 'La tontine ne peut pas être démarrée dans son état actuel' });
    }

    // Check if group has enough members
    const maxMembres = groupRows[0].max_membres;
    const [memberCountRows] = await db.query(
      'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut = ?',
      [groupId, 'approuvé']
    );
    const membresActuels = memberCountRows[0]?.count || 0;

    if (membresActuels < maxMembres) {
      const membresManquants = maxMembres - membresActuels;
      return res.status(400).json({
        message: `Impossible de démarrer la tontine. Il manque encore ${membresManquants} membres. Vous avez ${membresActuels} membres sur ${maxMembres} requis.`,
        membres_actuels: membresActuels,
        membres_requis: maxMembres,
        membres_manquants: membresManquants
      });
    }

    await db.query("UPDATE `groups` SET status = 'active', is_active = 1, date_demarrage = NOW() WHERE id = ?", [groupId]);
    await buildBeneficiaryOrder(groupId);
    await refreshGroupPlacesRestantes(groupId);

    res.json({ message: 'La tontine a été démarrée', status: 'active' });
  } catch (error) {
    console.error('Erreur démarrage groupe:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getGroupStatus = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT id, user_id, status, max_membres, places_restantes FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const group = groupRows[0];
    const [memberRows] = await db.query('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, userId]);
    if (memberRows.length === 0 && group.user_id !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [countRows] = await db.query('SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut != ?', [groupId, 'rejeté']);
    const currentMembers = countRows[0]?.count || 0;
    const placesRestantes = group.places_restantes != null ? group.places_restantes : Math.max(group.max_membres - currentMembers, 0);

    res.json({
      status: group.status,
      placesRestantes,
      currentMembers,
    });
  } catch (error) {
    console.error('Erreur getGroupStatus:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getPublicGroups = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT g.id, g.nom, g.montant, g.frequence, g.max_membres, g.type, g.code_invitation, g.created_at,
        u.nom as createur_nom,
        COUNT(gm.id) as nombre_membres
       FROM \`groups\` g
       LEFT JOIN users u ON g.user_id = u.id
       LEFT JOIN group_members gm ON g.id = gm.group_id AND gm.statut = 'approuvé'
       WHERE (g.status = 'recrutement' OR g.is_active = 0) AND g.type = 'public'
       GROUP BY g.id
       ORDER BY g.created_at DESC`
    );

    const groups = rows.map((row) => {
      const nombreMembres = Number(row.nombre_membres);
      const maxMembres = Number(row.max_membres);
      const placesRestantes = Math.max(maxMembres - nombreMembres, 0);

      return {
        id: row.id,
        nom: row.nom,
        montant: Number(row.montant),
        frequence: row.frequence,
        max_membres: maxMembres,
        nombre_membres: nombreMembres,
        places_restantes: placesRestantes,
        createur_nom: row.createur_nom,
        type: row.type || 'public',
        code_invitation: row.code_invitation,
        commission_createur: Number(row.commission_createur || 5.0),
        created_at: row.created_at,
      };
    });

    res.json(groups);
  } catch (error) {
    console.error('Erreur getPublicGroups:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/groups/status/:groupId
exports.updateGroupStatus = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const { status } = req.body;
    const userId = req.user.userId;

    if (!status || !['recrutement', 'active', 'terminée'].includes(status)) {
      return res.status(400).json({ message: 'Statut invalide' });
    }

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    if (userId !== groupOwnerId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    if (status === 'active') {
      await db.query("UPDATE `groups` SET status = ?, date_demarrage = NOW() WHERE id = ?", [status, groupId]);
    } else {
      await db.query('UPDATE `groups` SET status = ? WHERE id = ?', [status, groupId]);
    }

    res.json({ message: `Statut du groupe mis à jour: ${status}` });
  } catch (error) {
    console.error('Erreur mise à jour statut groupe:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/groups/membres-statuts/:groupId
exports.getMembresStatuts = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    // Verify user is creator or member of the group
    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    const [memberRows] = await db.query('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, userId]);
    
    if (groupOwnerId !== userId && memberRows.length === 0) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    // Get all members with their payment status
    const [membres] = await db.query(
      `SELECT u.id as userId, u.nom, u.prenom, u.statut_paiement, u.jours_retard_max,
              (SELECT COUNT(*) FROM historique_retards hr WHERE hr.user_id = u.id AND hr.group_id = ? AND hr.statut = 'en_cours') as jours_retard,
              (SELECT COUNT(*) FROM payments p WHERE p.group_id = ? AND p.user_id = u.id AND p.statut = 'VALIDEE') as nb_paiements
       FROM group_members gm
       JOIN users u ON gm.user_id = u.id
       WHERE gm.group_id = ? AND gm.statut = 'approuvé'
       ORDER BY gm.joined_at ASC`,
      [groupId, groupId, groupId]
    );

    const membresAvecStatuts = membres.map(m => {
      const joursRetard = m.jours_retard || 0;
      let badgeCouleur = 'vert';
      if (m.statut_paiement === 'attention') {
        badgeCouleur = 'jaune';
      } else if (m.statut_paiement === 'en_retard') {
        badgeCouleur = 'rouge';
      } else if (m.statut_paiement === 'defaillant') {
        badgeCouleur = 'noir';
      }

      return {
        userId: m.userId,
        nom: m.nom,
        prenom: m.prenom,
        statut_paiement: m.statut_paiement,
        jours_retard: joursRetard,
        a_paye_ce_tour: m.nb_paiements > 0,
        badge_couleur: badgeCouleur
      };
    });

    // Calculate statistics
    const stats = {
      total: membresAvecStatuts.length,
      a_jour: membresAvecStatuts.filter(m => m.statut_paiement === 'fiable').length,
      attention: membresAvecStatuts.filter(m => m.statut_paiement === 'attention').length,
      en_retard: membresAvecStatuts.filter(m => m.statut_paiement === 'en_retard').length,
      defaillant: membresAvecStatuts.filter(m => m.statut_paiement === 'defaillant').length
    };

    res.json({
      membres: membresAvecStatuts,
      statistiques: stats
    });
  } catch (error) {
    console.error('Erreur getMembresStatuts:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
