const db = require('../config/db');

exports.getMesGroupes = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [rows] = await db.query(
      "SELECT DISTINCT g.id, g.nom, g.montant, g.frequence, g.is_active, g.max_membres, g.date_demarrage, " +
      "b.nom AS beneficiary_nom, b.telephone AS beneficiary_telephone " +
      "FROM `groups` g " +
      "LEFT JOIN `beneficiaries` b ON g.id = b.group_id AND b.is_next = 1 " +
      "LEFT JOIN group_members gm ON g.id = gm.group_id " +
      "WHERE g.user_id = ? OR gm.user_id = ?",
      [userId, userId]
    );

    // Obtenir le nombre de membres pour chaque groupe
    const groupes = [];
    for (const row of rows) {
      const [memberCount] = await db.query(
        'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut = ?',
        [row.id, 'approuvé']
      );
      const currentMembers = Number(memberCount[0].count) || 0;
      const maxMembers = row.max_membres || 10;
      const availableSlots = Math.max(0, maxMembers - currentMembers);

      let status = 'recrutement';
      try {
        const [statusRow] = await db.query(
          'SELECT status FROM `groups` WHERE id = ?',
          [row.id]
        );
        if (statusRow.length > 0 && statusRow[0].status) {
          status = statusRow[0].status;
        }
      } catch (e) {}

      groupes.push({
        id: row.id,
        nom: row.nom,
        montant: Number(row.montant),
        frequence: row.frequence,
        isActive: Boolean(row.is_active),
        status,
        startDate: row.date_demarrage,
        maxMembers,
        currentMembers,
        availableSlots,
        prochainBeneficiaire: row.beneficiary_nom
          ? {
              nom: row.beneficiary_nom,
              telephone: row.beneficiary_telephone,
            }
          : null,
      });
    }

    res.json(groupes);
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getTotalCotisations = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [rows] = await db.query(
      "SELECT COALESCE(SUM(montant), 0) AS total " +
      "FROM `payments` " +
      "WHERE user_id = ?",
      [userId]
    );

    const total = rows.length > 0 ? Number(rows[0].total) : 0;
    res.json({ total });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getProchainBeneficiaire = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);

    const [groupRows] = await db.query(
      'SELECT user_id FROM `groups` WHERE id = ?',
      [groupId]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }
    const groupOwnerId = groupRows[0].user_id;
    if (req.user.userId !== groupOwnerId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [rows] = await db.query(
      "SELECT nom, telephone " +
      "FROM `beneficiaries` " +
      "WHERE group_id = ? AND is_next = 1 " +
      "LIMIT 1",
      [groupId]
    );

    if (rows.length === 0) {
      return res.json({ groupId, prochainBeneficiaire: null });
    }

    res.json({
      groupId,
      prochainBeneficiaire: {
        nom: rows[0].nom,
        telephone: rows[0].telephone,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getGroupDetails = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query(
      'SELECT id, user_id, nom, montant, frequence, max_membres, code_invitation, is_active, status, date_demarrage, created_at FROM `groups` WHERE id = ?',
      [groupId]
    );
    
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const group = groupRows[0];
    
    // Verify that user is owner or member
    if (userId !== group.user_id) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ? AND statut = ?',
        [groupId, userId, 'approuvé']
      );
      if (memberRows.length === 0) {
        return res.status(403).json({ message: 'Accès refusé' });
      }
    }

    // Get next beneficiary
    const [beneficiaryRows] = await db.query(
      "SELECT nom, telephone FROM `beneficiaries` WHERE group_id = ? AND is_next = 1 LIMIT 1",
      [groupId]
    );

    // Get member count
    const [memberCountRows] = await db.query(
      'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut = ?',
      [groupId, 'approuvé']
    );
    const currentMembers = memberCountRows[0].count || 0;
    const maxMembers = group.max_membres || 10;
    const availableSlots = Math.max(0, maxMembers - currentMembers);

    const groupDetails = {
      id: group.id,
      nom: group.nom,
      montant: Number(group.montant),
      frequence: group.frequence,
      maxMembres: maxMembers,
      currentMembers,
      availableSlots,
      codeInvitation: group.code_invitation,
      isActive: Boolean(group.is_active),
      status: group.status || 'recrutement',
      startDate: group.date_demarrage,
      createdAt: group.created_at,
      isOwner: userId === group.user_id,
      isLocked: group.status === 'active',
      prochainBeneficiaire: beneficiaryRows.length > 0 ? {
        nom: beneficiaryRows[0].nom,
        telephone: beneficiaryRows[0].telephone,
      } : null,
    };

    res.json(groupDetails);
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/groups/membres/:groupId
exports.getGroupMembers = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;

    // Vérifier que l'utilisateur est membre ou créateur
    const [isMemberRows] = await db.query('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, userId]);
    if (isMemberRows.length === 0 && userId !== groupOwnerId) return res.status(403).json({ message: 'Accès refusé' });

    // Membres approuvés
    const [approved] = await db.query(
      'SELECT u.id as user_id, u.nom, u.telephone, gm.joined_at, b.ordre FROM group_members gm JOIN users u ON gm.user_id = u.id LEFT JOIN beneficiaries b ON b.group_id = gm.group_id AND b.telephone = u.telephone WHERE gm.group_id = ? AND gm.statut = ? ORDER BY (b.ordre IS NULL), b.ordre ASC, gm.joined_at ASC',
      [groupId, 'approuvé']
    );

    const members = approved.map(r => ({ userId: r.user_id, nom: r.nom, telephone: r.telephone, joinedAt: r.joined_at, ordre: r.ordre || null }));

    res.json(members);
  } catch (error) {
    console.error('Erreur getGroupMembers:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getGroupPayments = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;

    const [isMemberRows] = await db.query(
      'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupId, userId]
    );
    if (isMemberRows.length === 0 && userId !== groupOwnerId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [paymentRows] = await db.query(
      'SELECT p.id, p.montant, p.statut, p.created_at, u.nom as payer_nom, u.telephone as payer_telephone '
      + 'FROM payments p '
      + 'JOIN users u ON p.user_id = u.id '
      + 'WHERE p.group_id = ? '
      + 'ORDER BY p.created_at DESC',
      [groupId]
    );

    const payments = paymentRows.map((row) => ({
      id: row.id,
      montant: Number(row.montant),
      statut: row.statut,
      createdAt: row.created_at,
      payerNom: row.payer_nom,
      payerTelephone: row.payer_telephone,
    }));

    res.json(payments);
  } catch (error) {
    console.error('Erreur getGroupPayments:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/beneficiaries/groupe/:groupId
exports.getBeneficiairesGroupe = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);

    const [beneficiaries] = await db.query(
      'SELECT b.id, b.nom, b.telephone, b.ordre, gm.joined_at FROM beneficiaries b LEFT JOIN group_members gm ON gm.group_id = b.group_id AND gm.user_id = (SELECT id FROM users WHERE telephone = b.telephone) WHERE b.group_id = ? ORDER BY b.ordre ASC',
      [groupId]
    );

    const formatted = beneficiaries.map(b => ({
      id: b.id,
      nom: b.nom,
      telephone: b.telephone,
      ordre: b.ordre,
      dateEntree: b.joined_at,
    }));

    res.json(formatted);
  } catch (error) {
    console.error('Erreur getBeneficiairesGroupe:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/payments/user/:userId
exports.getUserPayments = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [payments] = await db.query(
      `SELECT p.*, g.nom as group_name
       FROM payments p
       JOIN \`groups\` g ON p.group_id = g.id
       WHERE p.user_id = ?
       ORDER BY p.created_at DESC`,
      [userId]
    );

    res.json(payments);
  } catch (error) {
    console.error('Erreur getUserPayments:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
