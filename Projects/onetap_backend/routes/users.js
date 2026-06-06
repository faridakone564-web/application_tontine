const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const userController = require('../controllers/userController');

router.get('/profil/:userId', authMiddleware, userController.getProfile);
router.get('/reputation/:userId', authMiddleware, userController.getReputation);
router.put('/modifier/:userId', authMiddleware, userController.updateProfile);

module.exports = router;
