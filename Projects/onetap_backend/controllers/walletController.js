const db = require('../config/db');

// Minimal wallet controller stub used by payments flow.
// Implementations are conservative to avoid breaking the server; extend as needed.

exports.processCotisation = async (userId, groupId, montant) => {
  // Attempt to update user wallet and record a transaction if tables exist.
  try {
    const [walletRows] = await db.query('SELECT solde FROM wallets WHERE user_id = ?', [userId]);
    if (walletRows.length === 0) {
      return { distribution: null };
    }

    // For now, do not modify balances here; paymentsController records the payment.
    return { distribution: null };
  } catch (error) {
    console.error('walletController.processCotisation error:', error.message);
    throw error;
  }
};

exports.distribuerAutomatique = async (groupId) => {
  // Placeholder: in production this would compute and distribute amounts to beneficiaries.
  try {
    // No-op
    return null;
  } catch (error) {
    console.error('walletController.distribuerAutomatique error:', error.message);
    throw error;
  }
};

exports.crediterPortefeuille = async (userId, montant) => {
  try {
    const [rows] = await db.query('SELECT solde FROM wallets WHERE user_id = ?', [userId]);
    if (rows.length === 0) {
      await db.query('INSERT INTO wallets (user_id, solde, total_depose, total_retire) VALUES (?, ?, ?, ?)', [userId, montant, montant, 0]);
      return { solde: montant };
    }
    const nouveau = parseFloat(rows[0].solde) + Number(montant);
    await db.query('UPDATE wallets SET solde = ?, total_depose = total_depose + ? WHERE user_id = ?', [nouveau, montant, userId]);
    return { solde: nouveau };
  } catch (error) {
    console.error('walletController.crediterPortefeuille error:', error.message);
    throw error;
  }
};
