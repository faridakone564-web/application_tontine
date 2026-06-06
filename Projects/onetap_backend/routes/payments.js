const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const paymentsController = require('../controllers/paymentsController');

router.post('/payer', authMiddleware, paymentsController.payer);
router.post('/simuler', authMiddleware, paymentsController.simulerPaiement);
router.get('/mes-paiements/:userId', authMiddleware, paymentsController.mesPaiements);
router.get('/total/:userId', authMiddleware, paymentsController.total);
router.put('/valider/:paymentId', authMiddleware, paymentsController.valider);

module.exports = router;
