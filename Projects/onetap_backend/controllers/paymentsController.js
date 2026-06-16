const db = require('../config/db');
const walletController = require('./walletController');

// POST /api/payments/payer - Enregistrer un paiement avec validation automatique
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
      'SELECT user_id, commission_createur FROM `groups` WHERE id = ?',
      [groupIdNumber]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    const commissionRate = groupRows[0].commission_createur != null ? parseFloat(groupRows[0].commission_createur) : 5.0;
    let isAuthorized = groupOwnerId === userIdNumber;
    if (!isAuthorized) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ? AND statut = ?',
        [groupIdNumber, userIdNumber, 'approuvé']
      );
      isAuthorized = memberRows.length > 0;
    }

    if (!isAuthorized) {
      return res.status(403).json({ message: 'Accès refusé au groupe' });
    }

    // Calculer commissions
    const commissionPlateforme = 0; // OneTap ne prend aucune commission
    const commissionCreateur = parseFloat((amountNumber * (commissionRate / 100)).toFixed(2));
    const montantCoffre = amountNumber; // montant complet va au coffre

    // Insérer le paiement avec statut validé automatiquement
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
          montantCoffre,
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

    // Process wallet transactions
    let distribution = null;
    try {
      const result = await walletController.processCotisation(userIdNumber, groupIdNumber, amountNumber);
      distribution = result.distribution;
    } catch (walletError) {
      console.error('Erreur wallet lors du paiement:', walletError.message);
      // Continue even if wallet fails for now
    }

    // Update payment status in echeance system
    try {
      const { mettreAJourStatutPaiementMembre } = require('../services/echeanceService');
      await mettreAJourStatutPaiementMembre(userIdNumber, groupIdNumber);
    } catch (echeanceError) {
      console.error('Erreur mise à jour statut échéance:', echeanceError.message);
      // Continue even if echeance update fails
    }

    // Regularisation automatique des paiements en retard
    try {
      await regulariserPaiementEnRetard(userIdNumber, groupIdNumber);
    } catch (regularisationError) {
      console.error('Erreur régularisation paiement:', regularisationError.message);
      // Continue even if regularization fails
    }

    // Attempt automatic distribution to beneficiary
    try {
      await walletController.distribuerAutomatique(groupIdNumber);
    } catch (distError) {
      console.error('Erreur distribution automatique:', distError.message);
      // Continue even if distribution fails
    }

    res.json({
      message: 'Paiement enregistré avec succès',
      paymentId: paymentId,
      montant_total: amountNumber + commissionCreateur,
      repartition: distribution || {
        coffre_groupe: amountNumber,
        commission_createur: commissionCreateur,
        commission_plateforme: commissionPlateforme,
        coffre_actuel: amountNumber
      },
      simulation: false
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
      'SELECT user_id, commission_createur FROM `groups` WHERE id = ?',
      [groupIdNumber]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    const commissionRate = groupRows[0].commission_createur != null ? parseFloat(groupRows[0].commission_createur) : 5.0;
    let isAuthorized = groupOwnerId === userIdNumber;
    if (!isAuthorized) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ? AND statut = ?',
        [groupIdNumber, userIdNumber, 'approuvé']
      );
      isAuthorized = memberRows.length > 0;
    }

    if (!isAuthorized) {
      return res.status(403).json({ message: 'Accès refusé au groupe' });
    }

    // Calculer commissions
    const commissionPlateforme = 0; // OneTap ne prend aucune commission
    const commissionCreateur = parseFloat((amountNumber * (commissionRate / 100)).toFixed(2));
    const montantCoffre = amountNumber; // montant complet va au coffre

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
          montantCoffre,
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

    // Process wallet transactions
    let distribution = null;
    try {
      const result = await walletController.processCotisation(userIdNumber, groupIdNumber, amountNumber);
      distribution = result.distribution;
    } catch (walletError) {
      console.error('Erreur wallet lors de la simulation:', walletError.message);
      // Continue even if wallet fails for now
    }

    // Attempt automatic distribution to beneficiary
    try {
      await walletController.distribuerAutomatique(groupIdNumber);
    } catch (distError) {
      console.error('Erreur distribution automatique:', distError.message);
      // Continue even if distribution fails
    }

    res.json({
      message: 'Paiement enregistré avec succès',
      montant_total: amountNumber + commissionCreateur,
      repartition: distribution || {
        coffre_groupe: amountNumber,
        commission_createur: commissionCreateur,
        commission_plateforme: commissionPlateforme,
        coffre_actuel: amountNumber
      },
      simulation: true
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

// Regularisation automatique des paiements en retard
async function regulariserPaiementEnRetard(userId, groupId) {
  try {
    // Mettre à jour les retards en cours pour cet utilisateur et ce groupe
    await db.query(
      `UPDATE historique_retards 
       SET statut = 'regularise', date_paiement = CURDATE()
       WHERE user_id = ? AND group_id = ? AND statut = 'en_cours'`,
      [userId, groupId]
    );

    // Vérifier s'il y a encore des retards en cours pour cet utilisateur
    const [retardsEnCours] = await db.query(
      `SELECT COUNT(*) as count FROM historique_retards 
       WHERE user_id = ? AND statut = 'en_cours'`,
      [userId]
    );

    // Si plus aucun retard en cours, remettre le statut à 'fiable'
    if (retardsEnCours[0].count === 0) {
      await db.query(
        `UPDATE users SET statut_paiement = 'fiable', derniere_regularisation = CURDATE() WHERE id = ?`,
        [userId]
      );
    } else {
      // Sinon, mettre à jour la date de régularisation
      await db.query(
        `UPDATE users SET derniere_regularisation = CURDATE() WHERE id = ?`,
        [userId]
      );
    }

    console.log(`Régularisation paiement effectuée pour user ${userId}, group ${groupId}`);
  } catch (error) {
    console.error('Erreur régularisation paiement:', error);
    throw error;
  }
}

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
    const commissionPlateforme = 0;
    const commissionCreateur = parseFloat((amount * 0.05).toFixed(2));
    const montantNet = amount;

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

    // Process wallet transactions
    try {
      await walletController.processCotisation(payment.user_id, payment.group_id, amount);
    } catch (walletError) {
      console.error('Erreur wallet lors de la validation:', walletError.message);
      // Continue even if wallet fails for now
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
