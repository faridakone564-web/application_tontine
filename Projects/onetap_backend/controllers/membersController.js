const db = require('../config/db');

async function rebuildBeneficiariesForGroup(groupId) {
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

async function refreshGroupPlacesRestantes(groupId) {
  const [rows] = await db.query('SELECT COUNT(*) AS count FROM group_members WHERE group_id = ? AND statut != ?', [groupId, 'rejeté']);
  const currentCount = rows[0]?.count || 0;
  await db.query('UPDATE `groups` SET places_restantes = GREATEST(max_membres - ?, 0) WHERE id = ?', [currentCount, groupId]);
}

// POST /api/members/rejoindre
async function envoyerNotification(userId, message, type = 'info') {
  try {
    await db.query(
      'INSERT INTO notifications (user_id, titre, message, type, lu) VALUES (?, ?, ?, ?, 0)',
      [userId, message, message, type]
    );
  } catch (error) {
    console.error('Erreur envoyerNotification:', error.message);
  }
}

exports.rejoindre = async (req, res) => {
  try {
    const { codeInvitation, groupId } = req.body;
    const userId = req.user.userId;

    if (!codeInvitation && !groupId) {
      return res.status(400).json({ message: 'Code d\'invitation ou identifiant de groupe requis' });
    }

    // Vérifier le statut de paiement de l'utilisateur
    const [userStatus] = await db.query(
      'SELECT statut_paiement, jours_retard_max FROM users WHERE id = ?',
      [userId]
    );

    if (userStatus.length > 0) {
      const statutPaiement = userStatus[0].statut_paiement;

      if (statutPaiement === 'en_retard') {
        return res.status(403).json({
          message: 'Vous avez des paiements en retard. Regularisez vos cotisations avant de rejoindre une nouvelle tontine.',
          blocked: true
        });
      }

      if (statutPaiement === 'defaillant') {
        return res.status(403).json({
          message: 'Votre compte est signalé pour défaillance de paiement. Vous ne pouvez pas rejoindre de nouvelles tontines.',
          blocked: true
        });
      }

      if (statutPaiement === 'attention') {
        // Laisser passer mais inclure un avertissement dans la réponse
        const joursRetard = userStatus[0].jours_retard_max || 0;
        console.log(`Attention: User ${userId} a un paiement en retard de ${joursRetard} jours`);
      }
    }

    let groupe;
    let requestType = 'code';
    let invitationCode = null;

    if (codeInvitation) {
      const [groupRows] = await db.query(
        'SELECT id, user_id, nom, max_membres, status FROM `groups` WHERE code_invitation = ?',
        [codeInvitation]
      );
      if (groupRows.length === 0) return res.status(404).json({ message: 'Code d\'invitation invalide' });
      groupe = groupRows[0];
      invitationCode = codeInvitation;
    } else {
      const [groupRows] = await db.query(
        'SELECT id, user_id, nom, max_membres, status, type, code_invitation FROM `groups` WHERE id = ?',
        [groupId]
      );
      if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
      groupe = groupRows[0];
      if (groupe.type !== 'public') {
        return res.status(403).json({ message: 'Ce groupe nécessite un code d\'invitation' });
      }
      requestType = 'public';
    }

    // Vérifier si la tontine est en phase de recrutement
    if (groupe.status !== 'recrutement') {
      return res.status(403).json({ message: 'Cette tontine a déjà démarré ou est terminée. Les inscriptions sont fermées.' });
    }

    if (groupe.user_id === userId) return res.status(400).json({ message: 'Vous êtes déjà le créateur de ce groupe' });

    const [existing] = await db.query('SELECT id, statut FROM group_members WHERE group_id = ? AND user_id = ?', [groupe.id, userId]);
    if (existing.length > 0) return res.status(400).json({ message: 'Vous avez déjà rejoint ce groupe' });

    const [countRows] = await db.query('SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut != ?', [groupe.id, 'rejeté']);
    const membreCount = countRows[0].count || 0;
    if (membreCount >= groupe.max_membres) return res.status(400).json({ message: 'Ce groupe a atteint le nombre maximum de membres' });

    await db.query(
      'INSERT INTO group_members (group_id, user_id, statut, request_type, invitation_code) VALUES (?, ?, ?, ?, ?)',
      [groupe.id, userId, 'en_attente', requestType, invitationCode]
    );
    await refreshGroupPlacesRestantes(groupe.id);

    await envoyerNotification(
      groupe.user_id,
      `Nouvelle demande d'adhésion pour la tontine ${groupe.nom}`,
      'demande_adhesion'
    );

    res.json({ message: 'Votre demande d\'adhésion a été envoyée (en attente d\'approbation)' });
  } catch (error) {
    console.error('Erreur rejoindre membre:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/members/en-attente/:groupId
exports.getEnAttente = async (req, res) => {
  try {
    const groupId = parseInt(req.params.groupId, 10);
    const userId = req.user.userId;

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [groupId]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;
    if (groupOwnerId !== userId) return res.status(403).json({ message: 'Accès refusé' });

    const [rows] = await db.query(
      'SELECT gm.id as member_id, u.id as user_id, u.nom, u.telephone, gm.joined_at, gm.request_type FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = ? AND gm.statut = ? ORDER BY FIELD(gm.request_type, ?, ?) ASC, gm.joined_at ASC',
      [groupId, 'en_attente', 'code', 'public']
    );

    res.json(rows.map(r => ({
      memberId: r.member_id,
      userId: r.user_id,
      nom: r.nom,
      telephone: r.telephone,
      joinedAt: r.joined_at,
      requestType: r.request_type,
    })));
  } catch (error) {
    console.error('Erreur getEnAttente:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/members/approuver/:memberId
exports.approuver = async (req, res) => {
  try {
    const memberId = parseInt(req.params.memberId, 10);
    const userId = req.user.userId;

    const [memberRows] = await db.query('SELECT * FROM group_members WHERE id = ?', [memberId]);
    if (memberRows.length === 0) return res.status(404).json({ message: 'Membre introuvable' });
    const member = memberRows[0];

    const [groupRows] = await db.query('SELECT user_id, nom FROM `groups` WHERE id = ?', [member.group_id]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;
    if (groupOwnerId !== userId) return res.status(403).json({ message: 'Accès refusé' });

    // Mettre à jour le statut
    await db.query("UPDATE group_members SET statut = 'approuvé' WHERE id = ?", [memberId]);
    await refreshGroupPlacesRestantes(member.group_id);

    await envoyerNotification(
      member.user_id,
      `Votre demande d'adhésion a été approuvée pour la tontine ${groupRows[0].nom}`,
      'demande_adhesion'
    );

    const [approvedFocused] = await db.query(
      'SELECT id FROM group_members WHERE group_id = ? AND statut = ? ORDER BY joined_at ASC',
      [member.group_id, 'approuvé']
    );
    const ordre = approvedFocused.findIndex((row) => row.id === memberId) + 1;

    await rebuildBeneficiariesForGroup(member.group_id);

    res.json({ message: 'Membre approuvé', ordre });
  } catch (error) {
    console.error('Erreur approuver membre:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/members/rejeter/:memberId
exports.rejeter = async (req, res) => {
  try {
    const memberId = parseInt(req.params.memberId, 10);
    const userId = req.user.userId;

    const [memberRows] = await db.query('SELECT * FROM group_members WHERE id = ?', [memberId]);
    if (memberRows.length === 0) return res.status(404).json({ message: 'Membre introuvable' });
    const member = memberRows[0];

    const [groupRows] = await db.query('SELECT user_id, nom FROM `groups` WHERE id = ?', [member.group_id]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;
    if (groupOwnerId !== userId) return res.status(403).json({ message: 'Accès refusé' });

    await db.query("UPDATE group_members SET statut = 'rejeté' WHERE id = ?", [memberId]);
    await refreshGroupPlacesRestantes(member.group_id);

    await envoyerNotification(
      member.user_id,
      `Votre demande d'adhésion a été rejetée pour la tontine ${groupRows[0].nom}`,
      'demande_adhesion'
    );

    res.json({ message: 'Membre rejeté' });
  } catch (error) {
    console.error('Erreur rejeter membre:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
