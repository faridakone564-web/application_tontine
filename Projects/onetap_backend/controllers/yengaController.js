const axios = require('axios');
const db = require('../config/db');
const commissionController = require('./commissionController');
require('dotenv').config();

const YENGAPAY_BASE_URL = (process.env.YENGAPAY_BASE_URL || '').trim().replace(/\/+$/, '');
const YENGAPAY_API_PATH = YENGAPAY_BASE_URL.includes('/api/v1') ? '' : '/api/v1';
const YENGAPAY_API_KEY = process.env.YENGAPAY_API_KEY;
const YENGAPAY_ORGANIZATION_ID = process.env.YENGAPAY_ORGANIZATION_ID;
const YENGAPAY_PROJECT_ID = process.env.YENGAPAY_PROJECT_ID;

function ensureYengaConfig() {
  const missing = [];
  if (!YENGAPAY_BASE_URL) missing.push('YENGAPAY_BASE_URL');
  if (!YENGAPAY_API_KEY) missing.push('YENGAPAY_API_KEY');
  if (!YENGAPAY_ORGANIZATION_ID) missing.push('YENGAPAY_ORGANIZATION_ID');
  if (!YENGAPAY_PROJECT_ID) missing.push('YENGAPAY_PROJECT_ID');
  if (missing.length) {
    throw new Error(`Configuration YengaPay manquante: ${missing.join(', ')}`);
  }
}

function yengaHeaders() {
  return {
    'Content-Type': 'application/json',
    'x-api-key': YENGAPAY_API_KEY,
  };
}

// Initialiser un paiement YengaPay
exports.initierPaiement = async (req, res) => {
  try {
    const { montant, reference } = req.body;

    if (!montant || !reference) {
      return res.status(400).json({ message: 'Montant et référence requis' });
    }

    ensureYengaConfig();
    const url = `${YENGAPAY_BASE_URL}${YENGAPAY_API_PATH}/groups/${YENGAPAY_ORGANIZATION_ID}/payment-intent/${YENGAPAY_PROJECT_ID}`;
    const headers = yengaHeaders();
    console.log('YengaPay API Request:', {
      url,
      headers,
      body: {
        amount: montant,
        currency: 'XOF',
        reference,
      },
    });
    const response = await axios.post(
      url,
      {
        amount: montant,
        currency: 'XOF',
        reference,
      },
      {
        headers,
      }
    );

    res.json({
      paymentIntentId: response.data.id,
      amount: response.data.amount,
      currency: response.data.currency,
      status: response.data.status,
    });
  } catch (error) {
    console.error('Erreur initiation paiement YengaPay:', error.response?.data || error.message);
    res.status(500).json({
      message: 'Erreur lors de l\'initiation du paiement',
      error: error.response?.data || error.message
    });
  }
};

// Payer la cotisation via YengaPay
exports.payerCotisation = async (req, res) => {
  try {
    const { paymentIntentId, operatorCode, countryCode, customerMSISDN, groupId } = req.body;
    const groupIdNumber = Number(groupId);

    if (
      !paymentIntentId ||
      !operatorCode ||
      !countryCode ||
      !customerMSISDN ||
      !Number.isInteger(groupIdNumber) ||
      groupIdNumber <= 0
    ) {
      return res.status(400).json({
        message: 'paymentIntentId, operatorCode, countryCode, customerMSISDN et groupId requis',
      });
    }

    const userId = req.user?.userId;
    if (!userId) {
      return res.status(401).json({ message: 'Utilisateur non authentifié' });
    }

    const [groupRows] = await db.query(
      'SELECT user_id FROM `groups` WHERE id = ?',
      [groupIdNumber]
    );
    if (groupRows.length === 0) {
      return res.status(404).json({ message: 'Groupe introuvable' });
    }

    const groupOwnerId = groupRows[0].user_id;
    let isAuthorized = groupOwnerId === userId;
    if (!isAuthorized) {
      const [memberRows] = await db.query(
        'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
        [groupIdNumber, userId]
      );
      isAuthorized = memberRows.length > 0;
    }

    if (!isAuthorized) {
      return res.status(403).json({ message: 'Accès refusé au groupe' });
    }

    ensureYengaConfig();
    const response = await axios.post(
      `${YENGAPAY_BASE_URL}${YENGAPAY_API_PATH}/groups/${YENGAPAY_ORGANIZATION_ID}/payment-intent/${paymentIntentId}/pay`,
      {
        operator_code: operatorCode,
        country_code: countryCode,
        customer_msisdn: customerMSISDN,
      },
      {
        headers: yengaHeaders(),
      }
    );

    const status = response.data.status;
    const validStatuses = ['DONE', 'VALIDEE', 'PAID', 'SUCCESS'];
    const paymentStatut = validStatuses.includes(status ? status.toString().toUpperCase() : '')
      ? 'VALIDEE'
      : 'PENDING';
    const amount = Number(response.data.amount || 0);

    await db.query(
      'INSERT INTO payments (group_id, user_id, montant, statut) VALUES (?, ?, ?, ?)',
      [groupIdNumber, userId, amount, paymentStatut]
    );

    let commissionData = null;

    // Enregistrer la commission si le paiement est validé
    if (paymentStatut === 'VALIDEE') {
      const [paymentResult] = await db.query(
        'SELECT id FROM payments WHERE group_id = ? AND user_id = ? ORDER BY id DESC LIMIT 1',
        [groupIdNumber, userId]
      );

      if (paymentResult.length > 0) {
        const paymentId = paymentResult[0].id;
        const [groupResult] = await db.query(
          'SELECT user_id FROM `groups` WHERE id = ?',
          [groupIdNumber]
        );

        if (groupResult.length > 0) {
          const createurId = groupResult[0].user_id;
          await db.query(
            `INSERT INTO commissions (payment_id, group_id, createur_id, montant_total, commission_plateforme, commission_createur, montant_net)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
              paymentId,
              groupIdNumber,
              createurId,
              amount,
              commissionController.calculerCommission(amount).commission_plateforme,
              commissionController.calculerCommission(amount).commission_createur,
              commissionController.calculerCommission(amount).montant_net,
            ]
          );

          commissionData = commissionController.calculerCommission(amount);
        }
      }

      // Activer la tontine à la première cotisation enregistrée
      const [groupCheck] = await db.query(
        'SELECT status, date_demarrage FROM `groups` WHERE id = ? AND status = ?',
        [groupIdNumber, 'recrutement']
      );
      if (groupCheck.length > 0) {
        // C'est la première cotisation validée, activer la tontine
        await db.query(
          "UPDATE `groups` SET status = 'active', date_demarrage = NOW() WHERE id = ?",
          [groupIdNumber]
        );
      }
    }

    res.json({
      paymentIntentId: response.data.id,
      status: response.data.status,
      transactionId: response.data.transaction_id,
      amount: response.data.amount,
      currency: response.data.currency,
      ...(commissionData && {
        montant_total: amount,
        commission_plateforme: commissionData.commission_plateforme,
        commission_createur: commissionData.commission_createur,
        montant_net: commissionData.montant_net,
      }),
    });
  } catch (error) {
    console.error('Erreur paiement YengaPay:', error.response?.data || error.message);
    res.status(500).json({
      message: 'Erreur lors du paiement',
      error: error.response?.data || error.message,
    });
  }
};

// Vérifier le statut du paiement
exports.verifierStatut = async (req, res) => {
  try {
    const { paymentIntentId } = req.params;

    if (!paymentIntentId) {
      return res.status(400).json({ message: 'paymentIntentId requis' });
    }

    ensureYengaConfig();
    const response = await axios.get(
      `${YENGAPAY_BASE_URL}${YENGAPAY_API_PATH}/groups/${YENGAPAY_ORGANIZATION_ID}/payment-intent/${paymentIntentId}`,
      {
        headers: yengaHeaders(),
      }
    );

    res.json({
      paymentIntentId: response.data.id,
      status: response.data.status,
      amount: response.data.amount,
      currency: response.data.currency,
      reference: response.data.reference,
      createdAt: response.data.created_at,
      updatedAt: response.data.updated_at,
    });
  } catch (error) {
    console.error('Erreur vérification statut YengaPay:', error.response?.data || error.message);
    res.status(500).json({
      message: 'Erreur lors de la vérification du statut',
      error: error.response?.data || error.message
    });
  }
};
