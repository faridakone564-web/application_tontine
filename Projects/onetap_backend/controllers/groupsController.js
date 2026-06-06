const db = require('../config/db');

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
      joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY unique_member (group_id, user_id)
    )
  `);
}

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
      'INSERT INTO beneficiaries (group_id, nom, telephone, ordre, is_next) VALUES (?, ?, ?, ?, ?)',
      [groupId, member.nom, member.telephone, ordre, ordre === 1 ? 1 : 0]
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

    const frequencesValides = ['quotidien', 'hebdomadaire', 'mensuel'];
    if (!frequencesValides.includes(frequence.toLowerCase())) {
      return res.status(400).json({ message: 'Fréquence invalide. Valeurs acceptées: quotidien, hebdomadaire, mensuel' });
    }

    const typesValides = ['public', 'privé'];
    const groupeType = typesValides.includes((type || '').toLowerCase()) ? type.toLowerCase() : 'privé';

    let codeInvitation;
    let codeExists;
    do {
      codeInvitation = generateInvitationCode();
      const [existing] = await db.query('SELECT id FROM `groups` WHERE code_invitation = ?', [codeInvitation]);
      codeExists = existing.length > 0;
    } while (codeExists);

    const [result] = await db.query(
      'INSERT INTO `groups` (user_id, nom, montant, frequence, max_membres, type, code_invitation, places_restantes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, nom, montant, frequence, max_membres, groupeType, codeInvitation, Math.max(max_membres - 1, 0)]
    );

    await ensureGroupMembersTable();
    await db.query('INSERT INTO group_members (group_id, user_id, statut) VALUES (?, ?, ?)', [result.insertId, userId, 'approuvé']);

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

// Rejoindre un groupe avec un code d'invitation
exports.rejoindreGroupe = async (req, res) => {
  try {
    const { code_invitation, codeInvitation } = req.body;
    const invitation = code_invitation || codeInvitation;
    const userId = req.user.userId;

    if (!invitation) {
      return res.status(400).json({ message: 'Code d\'invitation requis' });
    }

    const [groupRows] = await db.query(
      'SELECT id, user_id, nom, max_membres, status FROM `groups` WHERE code_invitation = ?',
      [invitation]
    );

    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Code d\'invitation invalide' });
    }

    const groupe = groupRows[0];
    if (groupe.user_id === userId) {
      return res.status(400).json({ message: 'Vous êtes déjà le créateur de ce groupe' });
    }

    if (groupe.status !== 'recrutement') {
      return res.status(403).json({ message: 'Cette tontine a déjà démarré ou est terminée. Les inscriptions sont fermées.' });
    }

    await ensureGroupMembersTable();

    const [existing] = await db.query('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [groupe.id, userId]);
    if (existing.length > 0) {
      return res.status(400).json({ message: 'Vous avez déjà rejoint ce groupe' });
    }

    const [countRows] = await db.query('SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut != ?', [groupe.id, 'rejeté']);
    const membreCount = countRows[0]?.count || 0;
    if (membreCount >= groupe.max_membres) {
      return res.status(400).json({ message: 'Ce groupe a atteint le nombre maximum de membres' });
    }

    await db.query('INSERT INTO group_members (group_id, user_id, statut) VALUES (?, ?, ?)', [groupe.id, userId, 'en_attente']);
    await refreshGroupPlacesRestantes(groupe.id);

    res.json({
      message: 'Votre demande d\'adhésion a été envoyée (en attente d\'approbation)',
      groupe: {
        id: groupe.id,
        nom: groupe.nom,
      },
    });
  } catch (error) {
    console.error('Erreur rejoindre groupe:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.demarrerGroupe = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT user_id, status FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    if (groupRows[0].user_id !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    if (groupRows[0].status !== 'recrutement') {
      return res.status(400).json({ message: 'La tontine ne peut pas être démarrée dans son état actuel' });
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
    const [rows] = await db.query(
      `SELECT g.id, g.nom, g.montant, g.frequence, g.max_membres, g.places_restantes,
        COALESCE(member_count.count, 0) AS currentMembers,
        u.nom AS organizerName,
        u.score_reputation AS organizerScore,
        g.created_at,
        g.code_invitation
      FROM \`groups\` g
      JOIN users u ON g.user_id = u.id
      LEFT JOIN (
        SELECT group_id, COUNT(*) AS count
        FROM group_members
        WHERE statut != 'rejeté'
        GROUP BY group_id
      ) AS member_count ON member_count.group_id = g.id
      WHERE g.type = 'public' AND g.status = 'recrutement'
      ORDER BY g.created_at DESC`
    );

    const groups = rows.map((row) => ({
      id: row.id,
      nom: row.nom,
      montant: Number(row.montant),
      frequence: row.frequence,
      maxMembres: row.max_membres,
      currentMembers: Number(row.currentMembers),
      placesRestantes: Number(row.places_restantes ?? Math.max(row.max_membres - row.currentMembers, 0)),
      organizerName: row.organizerName,
      organizerScore: row.organizerScore != null ? Number(row.organizerScore) : 100,
      createdAt: row.created_at,
      codeInvitation: row.code_invitation,
    }));

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
