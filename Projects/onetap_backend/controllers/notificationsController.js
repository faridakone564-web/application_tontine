const db = require('../config/db');

// GET /api/notifications/:userId - Récupérer toutes les notifications d'un utilisateur
exports.getNotifications = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [notifications] = await db.query(
      'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC',
      [userId]
    );

    res.json(notifications);
  } catch (error) {
    console.error('Erreur récupération notifications:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/notifications/:notificationId/lire - Marquer une notification comme lue
exports.markAsRead = async (req, res) => {
  try {
    const notificationId = parseInt(req.params.notificationId, 10);
    const userId = req.user.userId;

    // Vérifier que la notification appartient à l'utilisateur
    const [notificationRows] = await db.query(
      'SELECT user_id FROM notifications WHERE id = ?',
      [notificationId]
    );

    if (notificationRows.length === 0) {
      return res.status(404).json({ message: 'Notification introuvable' });
    }

    if (notificationRows[0].user_id !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    await db.query(
      'UPDATE notifications SET lu = 1 WHERE id = ?',
      [notificationId]
    );

    res.json({ message: 'Notification marquée comme lue' });
  } catch (error) {
    console.error('Erreur marquer notification lue:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// PUT /api/notifications/:userId/tout-lire - Marquer toutes les notifications comme lues
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    await db.query(
      'UPDATE notifications SET lu = 1 WHERE user_id = ?',
      [userId]
    );

    res.json({ message: 'Toutes les notifications marquées comme lues' });
  } catch (error) {
    console.error('Erreur marquer toutes notifications lues:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// GET /api/notifications/:userId/non-lues - Récupérer les notifications non lues
exports.getUnreadCount = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [result] = await db.query(
      'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND lu = 0',
      [userId]
    );

    res.json({ count: result[0].count });
  } catch (error) {
    console.error('Erreur compteur notifications non lues:', error);
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
