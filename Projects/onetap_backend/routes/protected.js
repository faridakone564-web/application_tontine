const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');

// Exemple de route protégée
router.get('/profile', authMiddleware, (req, res) => {
  // req.user contient les données du token
  res.json({ message: 'Accès autorisé', user: req.user });
});

module.exports = router;
