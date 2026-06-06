const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const notificationsController = require('../controllers/notificationsController');

router.get('/:userId', authMiddleware, notificationsController.getNotifications);
router.get('/:userId/non-lues', authMiddleware, notificationsController.getUnreadCount);
router.put('/:notificationId/lire', authMiddleware, notificationsController.markAsRead);
router.put('/:userId/tout-lire', authMiddleware, notificationsController.markAllAsRead);

module.exports = router;
