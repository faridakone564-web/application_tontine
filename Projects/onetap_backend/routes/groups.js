const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const dashboardController = require('../controllers/dashboardController');
const groupsController = require('../controllers/groupsController');

router.get('/test', (req, res) => {
  res.json({ ok: true });
});

router.get('/mes-groupes/:userId', authMiddleware, dashboardController.getMesGroupes);
router.get('/details/:groupId', authMiddleware, dashboardController.getGroupDetails);
router.get('/membres/:groupId', authMiddleware, dashboardController.getGroupMembers);
router.get('/publics', authMiddleware, groupsController.getPublicGroups);
router.get('/statut/:groupId', authMiddleware, groupsController.getGroupStatus);
router.post('/creer', authMiddleware, groupsController.creerGroupe);
router.post('/rejoindre', authMiddleware, groupsController.rejoindreGroupe);
router.put('/status/:groupId', authMiddleware, groupsController.updateGroupStatus);
router.put('/demarrer/:groupId', authMiddleware, groupsController.demarrerGroupe);

module.exports = router;
