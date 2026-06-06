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
      'INSERT INTO beneficiaries (group_id, nom, telephone, ordre, is_next) VALUES (?, ?, ?, ?, ?)',
      [groupId, member.nom, member.telephone, ordre, ordre === 1 ? 1 : 0]
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
exports.rejoindre = async (req, res) => {
  try {
    const { codeInvitation } = req.body;
    const userId = req.user.userId;

    if (!codeInvitation) {
      return res.status(400).json({ message: 'Code d\'invitation requis' });
    }

    const [groupRows] = await db.query(
      'SELECT id, user_id, nom, max_membres, status FROM `groups` WHERE code_invitation = ?',
      [codeInvitation]
    );
    if (groupRows.length === 0) return res.status(404).json({ message: 'Code d\'invitation invalide' });
    const groupe = groupRows[0];

    // Vérifier si la tontine est verrouillée (active)
    if (groupe.status === 'active') {
      return res.status(403).json({ message: 'Cette tontine a déjà démarré. Les inscriptions sont fermées.' });
    }

    if (groupe.user_id === userId) return res.status(400).json({ message: 'Vous êtes déjà le créateur de ce groupe' });

    // Create group_members table if not exists (handled in index but keep safe)
    await db.query(`CREATE TABLE IF NOT EXISTS group_members (
      id INT AUTO_INCREMENT PRIMARY KEY,
      group_id INT NOT NULL,
      user_id INT NOT NULL,
      statut ENUM('en_attente','approuvé','rejeté') NOT NULL DEFAULT 'en_attente',
      joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (group_id) REFERENCES \`groups\`(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
      UNIQUE KEY unique_member (group_id, user_id)
    )`);

    const [existing] = await db.query('SELECT id, statut FROM group_members WHERE group_id = ? AND user_id = ?', [groupe.id, userId]);
    if (existing.length > 0) return res.status(400).json({ message: 'Vous avez déjà rejoint ce groupe' });

    const [countRows] = await db.query('SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut != ?', [groupe.id, 'rejeté']);
    const membreCount = countRows[0].count || 0;
    if (membreCount >= groupe.max_membres) return res.status(400).json({ message: 'Ce groupe a atteint le nombre maximum de membres' });

    await db.query('INSERT INTO group_members (group_id, user_id, statut) VALUES (?, ?, ?)', [groupe.id, userId, 'en_attente']);
    await refreshGroupPlacesRestantes(groupe.id);

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
      'SELECT gm.id as member_id, u.id as user_id, u.nom, u.telephone, gm.joined_at FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = ? AND gm.statut = ? ORDER BY gm.joined_at ASC',
      [groupId, 'en_attente']
    );

    res.json(rows.map(r => ({ memberId: r.member_id, userId: r.user_id, nom: r.nom, telephone: r.telephone, joinedAt: r.joined_at })));
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

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [member.group_id]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;
    if (groupOwnerId !== userId) return res.status(403).json({ message: 'Accès refusé' });

    // Mettre à jour le statut
    await db.query("UPDATE group_members SET statut = 'approuvé' WHERE id = ?", [memberId]);
    await refreshGroupPlacesRestantes(member.group_id);

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

    const [groupRows] = await db.query('SELECT user_id FROM `groups` WHERE id = ?', [member.group_id]);
    if (groupRows.length === 0) return res.status(404).json({ message: 'Groupe introuvable' });
    const groupOwnerId = groupRows[0].user_id;
    if (groupOwnerId !== userId) return res.status(403).json({ message: 'Accès refusé' });

    await db.query("UPDATE group_members SET statut = 'rejeté' WHERE id = ?", [memberId]);
    await refreshGroupPlacesRestantes(member.group_id);

    res.json({ message: 'Membre rejeté' });
  } catch (error) {
    console.error('Erreur rejeter membre:', error.message);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
