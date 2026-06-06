const db = require('../config/db');

// Calculer les commissions
exports.calculerCommission = (montant) => {
  const commission_plateforme = montant * 0.01; // 1%
  const commission_createur = montant * 0.02; // 2%
  const montant_net = montant * 0.97; // 97%
  
  return {
    commission_plateforme: parseFloat(commission_plateforme.toFixed(2)),
    commission_createur: parseFloat(commission_createur.toFixed(2)),
    montant_net: parseFloat(montant_net.toFixed(2)),
  };
};

// Enregistrer une commission
exports.enregistrerCommission = async (req, res) => {
  try {
    const { payment_id, group_id, createur_id, montant_total } = req.body;

    if (!payment_id || !group_id || !createur_id || !montant_total) {
      return res.status(400).json({ message: 'payment_id, group_id, createur_id et montant_total requis' });
    }

    const commissions = exports.calculerCommission(montant_total);

    await db.query(
      `INSERT INTO commissions (payment_id, group_id, createur_id, montant_total, commission_plateforme, commission_createur, montant_net)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        payment_id,
        group_id,
        createur_id,
        montant_total,
        commissions.commission_plateforme,
        commissions.commission_createur,
        commissions.montant_net,
      ]
    );

    res.json({
      message: 'Commission enregistrée avec succès',
      ...commissions,
    });
  } catch (error) {
    console.error('Erreur enregistrement commission:', error);
    res.status(500).json({ message: 'Erreur lors de l\'enregistrement de la commission' });
  }
};

// Obtenir le total des commissions d'un groupe
exports.getCommissionsGroupe = async (req, res) => {
  try {
    const { groupId } = req.params;

    const [rows] = await db.query(
      `SELECT 
        SUM(commission_plateforme) as total_plateforme,
        SUM(commission_createur) as total_createur,
        SUM(montant_net) as total_net,
        COUNT(*) as nombre_paiements
       FROM commissions 
       WHERE group_id = ?`,
      [groupId]
    );

    res.json(rows[0] || {
      total_plateforme: 0,
      total_createur: 0,
      total_net: 0,
      nombre_paiements: 0,
    });
  } catch (error) {
    console.error('Erreur récupération commissions groupe:', error);
    res.status(500).json({ message: 'Erreur lors de la récupération des commissions du groupe' });
  }
};

// Obtenir le total des commissions gagnées par un créateur
exports.getCommissionsCreateur = async (req, res) => {
  try {
    const { userId } = req.params;

    const [rows] = await db.query(
      `SELECT 
        SUM(commission_createur) as total_commissions,
        COUNT(*) as nombre_groupes
       FROM commissions 
       WHERE createur_id = ?`,
      [userId]
    );

    res.json(rows[0] || {
      total_commissions: 0,
      nombre_groupes: 0,
    });
  } catch (error) {
    console.error('Erreur récupération commissions créateur:', error);
    res.status(500).json({ message: 'Erreur lors de la récupération des commissions du créateur' });
  }
};
