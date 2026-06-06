const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const dashboardController = require('../controllers/dashboardController');

router.get('/prochain/:groupId', authMiddleware, dashboardController.getProchainBeneficiaire);
router.get('/groupe/:groupId', authMiddleware, dashboardController.getBeneficiairesGroupe);

module.exports = router;
