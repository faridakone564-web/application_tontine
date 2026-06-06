const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const yengaController = require('../controllers/yengaController');

router.post('/initier', authMiddleware, yengaController.initierPaiement);
router.post('/payer', authMiddleware, yengaController.payerCotisation);
router.get('/statut/:paymentIntentId', authMiddleware, yengaController.verifierStatut);

module.exports = router;
