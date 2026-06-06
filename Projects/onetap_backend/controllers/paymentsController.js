const db = require('../config/db');

// POST /api/payments/payer - Enregistrer un paiement en attente
exports.payer = async (req, res) => {
  try {
    const { groupId, montant } = req.body;
    const userId = req.user.userId;

    if (!groupId || !montant) {
      return res.status(400).json({ message: 'groupId et montant requis' });
    }

    const userIdNumber = Number(userId);
    const groupIdNumber = Number(groupId);
    const amountNumber = Number(montant);

    // Vérifier que l'utilisateur est autorisé
    const [groupRows] = await db.query(
      'SELECT user_id FROM `groups` WHERE id = ?',
      [groupIdNumber]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    let isAuthorized = groupOwnerId === userIdNumber;
    if (!isAuthorized) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
        [groupIdNumber, userIdNumber]
      );
      isAuthorized = memberRows.length > 0;
    }

    if (!isAuthorized) {
      return res.status(403).json({ message: 'Accès refusé au groupe' });
    }

    // Insérer le paiement avec statut en_attente
    const [result] = await db.query(
      'INSERT INTO payments (group_id, user_id, montant, statut) VALUES (?, ?, ?, ?)',
      [groupIdNumber, userIdNumber, amountNumber, 'en_attente']
    );

    res.json({
      message: 'Paiement enregistré',
      paymentId: result.insertId,
    });
  } catch (error) {
    console.error('Erreur paiement:', error);
    res.status(500).json({ message: 'Erreur lors du paiement', error: error.message });
  }
};

// POST /api/payments/simuler - Simuler un paiement validé
exports.simulerPaiement = async (req, res) => {
  try {
    const { groupId, montant } = req.body;
    const userId = req.user.userId;

    if (!groupId || !montant) {
      return res.status(400).json({ message: 'groupId et montant requis' });
    }

    const userIdNumber = Number(userId);
    const groupIdNumber = Number(groupId);
    const amountNumber = Number(montant);

    // Vérifier que l'utilisateur est autorisé
    const [groupRows] = await db.query(
      'SELECT user_id FROM `groups` WHERE id = ?',
      [groupIdNumber]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    let isAuthorized = groupOwnerId === userIdNumber;
    if (!isAuthorized) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
        [groupIdNumber, userIdNumber]
      );
      isAuthorized = memberRows.length > 0;
    }

    if (!isAuthorized) {
      return res.status(403).json({ message: 'Accès refusé au groupe' });
    }

    // Calculer commissions
    const commissionPlateforme = amountNumber * 0.01;
    const commissionCreateur = amountNumber * 0.02;
    const montantNet = amountNumber * 0.97;

    // Insérer le paiement avec statut validé
    const [result] = await db.query(
      'INSERT INTO payments (group_id, user_id, montant, statut) VALUES (?, ?, ?, ?)',
      [groupIdNumber, userIdNumber, amountNumber, 'VALIDEE']
    );

    const paymentId = result.insertId;

    // Insérer la commission si la table existe
    try {
      await db.query(
        `INSERT INTO commissions (payment_id, group_id, createur_id, montant_total, commission_plateforme, commission_createur, montant_net)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          paymentId,
          groupIdNumber,
          groupOwnerId,
          amountNumber,
          commissionPlateforme,
          commissionCreateur,
          montantNet,
        ]
      );
    } catch (err) {
      console.log('Table commissions peut ne pas exister:', err.message);
    }

    // Activer la tontine si c'est le premier paiement validé
    const [groupCheck] = await db.query(
      'SELECT status FROM `groups` WHERE id = ? AND status = ?',
      [groupIdNumber, 'recrutement']
    );
    if (groupCheck.length > 0) {
      await db.query(
        "UPDATE `groups` SET status = 'active', date_demarrage = NOW() WHERE id = ?",
        [groupIdNumber]
      );
    }

    res.json({
      message: 'Paiement simulé avec succès',
      montant_total: amountNumber,
      commission_plateforme: commissionPlateforme,
      commission_createur: commissionCreateur,
      montant_net: montantNet,
    });
  } catch (error) {
    console.error('Erreur simulation paiement:', error);
    res.status(500).json({ message: 'Erreur lors de la simulation du paiement', error: error.message });
  }
};

// GET /api/payments/mes-paiements/:userId - Tous les paiements d'un utilisateur
exports.mesPaiements = async (req, res) => {
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
    console.error('Erreur mes paiements:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/payments/total/:userId - Total des paiements validés
exports.total = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [result] = await db.query(
      'SELECT COALESCE(SUM(montant), 0) as total FROM payments WHERE user_id = ? AND statut = ?',
      [userId, 'VALIDEE']
    );

    res.json({ total: Number(result[0].total) });
  } catch (error) {
    console.error('Erreur total paiements:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/payments/valider/:paymentId - Valider un paiement (créateur seulement)
exports.valider = async (req, res) => {
  try {
    const paymentId = parseInt(req.params.paymentId, 10);
    const userId = req.user.userId;

    // Récupérer le paiement et vérifier que l'utilisateur est le créateur du groupe
    const [paymentRows] = await db.query(
      `SELECT p.*, g.user_id as group_owner_id
       FROM payments p
       JOIN \`groups\` g ON p.group_id = g.id
       WHERE p.id = ?`,
      [paymentId]
    );

    if (paymentRows.length === 0) {
      return res.status(404).json({ message: 'Paiement introuvable' });
    }

    const payment = paymentRows[0];
    if (payment.group_owner_id !== userId) {
      return res.status(403).json({ message: 'Seul le créateur du groupe peut valider' });
    }

    // Mettre à jour le statut
    await db.query(
      "UPDATE payments SET statut = 'VALIDEE' WHERE id = ?",
      [paymentId]
    );

    // Calculer et insérer la commission
    const amount = Number(payment.montant);
    const commissionPlateforme = amount * 0.01;
    const commissionCreateur = amount * 0.02;
    const montantNet = amount * 0.97;

    try {
      await db.query(
        `INSERT INTO commissions (payment_id, group_id, createur_id, montant_total, commission_plateforme, commission_createur, montant_net)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [
          paymentId,
          payment.group_id,
          payment.group_owner_id,
          amount,
          commissionPlateforme,
          commissionCreateur,
          montantNet,
        ]
      );
    } catch (err) {
      console.log('Table commissions peut ne pas exister:', err.message);
    }

    res.json({
      message: 'Paiement validé avec succès',
      commission_plateforme: commissionPlateforme,
      commission_createur: commissionCreateur,
      montant_net: montantNet,
    });
  } catch (error) {
    console.error('Erreur validation paiement:', error);
    res.status(500).json({ message: 'Erreur lors de la validation', error: error.message });
  }
};
