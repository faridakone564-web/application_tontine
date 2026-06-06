const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const membersController = require('../controllers/membersController');

router.post('/rejoindre', authMiddleware, membersController.rejoindre);
router.get('/en-attente/:groupId', authMiddleware, membersController.getEnAttente);
router.put('/approuver/:memberId', authMiddleware, membersController.approuver);
router.put('/rejeter/:memberId', authMiddleware, membersController.rejeter);

module.exports = router;
