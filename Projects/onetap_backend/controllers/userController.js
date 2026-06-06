const db = require('../config/db');

exports.getProfile = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [users] = await db.query(
      'SELECT id, nom, prenom, telephone, ville, quartier, score_reputation, paiements_a_temps, paiements_en_retard, tontines_terminees FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur introuvable' });
    }

    const user = users[0];
    res.json({
      id: user.id,
      nom: user.nom,
      prenom: user.prenom,
      telephone: user.telephone,
      ville: user.ville,
      quartier: user.quartier,
      score_reputation: user.score_reputation,
      paiements_a_temps: user.paiements_a_temps,
      paiements_en_retard: user.paiements_en_retard,
      tontines_terminees: user.tontines_terminees,
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

exports.getReputation = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const [users] = await db.query(
      'SELECT score_reputation, paiements_a_temps, paiements_en_retard, tontines_terminees FROM users WHERE id = ?',
      [userId]
    );
    if (users.length === 0) {
      return res.status(404).json({ message: 'Utilisateur introuvable' });
    }

    const user = users[0];
    const score = Math.max(0, Math.min(500, Number(user.score_reputation || 0)));
    let niveau = 'Débutant';
    let couleur = '#FF0000';
    if (score > 350) {
      niveau = 'Exemplaire';
      couleur = '#2E7D32';
    } else if (score > 200) {
      niveau = 'Fiable';
      couleur = '#7CB342';
    } else if (score > 100) {
      niveau = 'Régulier';
      couleur = '#FF9800';
    }

    res.json({
      score,
      niveau,
      couleur,
      paiementsATemps: Number(user.paiements_a_temps || 0),
      paiementsEnRetard: Number(user.paiements_en_retard || 0),
      tontinesTerminees: Number(user.tontines_terminees || 0),
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

const normalizePhone = (value) => {
  if (value == null) return '';
  return value.toString().replace(/\D/g, '');
};

exports.updateProfile = async (req, res) => {
  try {
    const userId = parseInt(req.params.userId, 10);
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Accès refusé' });
    }

    const { nom, prenom, telephone, ville, quartier } = req.body;
    const cleanTelephone = normalizePhone(telephone);
    
    if (!nom || typeof nom !== 'string' || nom.trim().length < 2) {
      return res.status(400).json({ message: 'Nom invalide' });
    }
    if (!cleanTelephone || !/^\d{8,15}$/.test(cleanTelephone)) {
      return res.status(400).json({ message: 'Téléphone invalide (8-15 chiffres)' });
    }

    const [existing] = await db.query(
      'SELECT id FROM users WHERE telephone = ? AND id != ?',
      [cleanTelephone, userId]
    );
    if (existing.length > 0) {
      return res.status(400).json({ message: 'Téléphone déjà utilisé' });
    }

    await db.query(
      'UPDATE users SET nom = ?, prenom = ?, telephone = ?, ville = ?, quartier = ? WHERE id = ?',
      [nom.trim(), prenom?.trim() || '', cleanTelephone, ville?.trim() || '', quartier?.trim() || '', userId]
    );

    res.json({
      message: 'Profil mis à jour avec succès',
      user: { id: userId, nom: nom.trim(), prenom: prenom?.trim() || '', telephone: cleanTelephone, ville: ville?.trim() || '', quartier: quartier?.trim() || '' },
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
