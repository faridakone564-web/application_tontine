const express = require('express');
const router = express.Router();
const commissionController = require('../controllers/commissionController');

// POST /api/commissions/enregistrer
router.post('/enregistrer', commissionController.enregistrerCommission);

// GET /api/commissions/groupe/:groupId
router.get('/groupe/:groupId', commissionController.getCommissionsGroupe);

// GET /api/commissions/createur/:userId
router.get('/createur/:userId', commissionController.getCommissionsCreateur);

module.exports = router;
