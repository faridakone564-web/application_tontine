const db = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const normalizePhone = (value) => {
  if (value == null) return '';
  return value.toString().replace(/\D/g, '');
};

// Inscription
exports.inscription = async (req, res) => {
  try {
    const {
      nom,
      prenom,
      telephone,
      age,
      ville,
      quartier,
      numero_cnib,
      pin,
      numero_urgence,
      nom_urgence,
      photo_profil,
      contrat_accepte,
    } = req.body;

    const villesValides = [
      'Ouagadougou',
      'Bobo-Dioulasso',
      'Koudougou',
      'Banfora',
      'Ouahigouya',
      'Pouytenga',
      'Kaya',
      'Tenkodogo',
      'Fada N\'Gourma',
      'D\'édougou',
    ];

    if (!nom || typeof nom !== 'string' || nom.trim().length < 2) {
      return res.status(400).json({ message: 'Nom invalide' });
    }
    if (!prenom || typeof prenom !== 'string' || prenom.trim().length < 2) {
      return res.status(400).json({ message: 'Prénom invalide' });
    }

    const ageNumber = Number(age);
    if (!Number.isInteger(ageNumber) || ageNumber < 18) {
      return res.status(400).json({
        message: 'Vous devez avoir au moins 18 ans pour utiliser OneTap Tontine',
      });
    }

    if (contrat_accepte !== true && contrat_accepte !== 'true') {
      return res.status(400).json({
        message: 'Vous devez accepter le contrat pour créer un compte',
      });
    }

    const cleanTelephone = normalizePhone(telephone);
    if (!cleanTelephone || !/^\d{8,15}$/.test(cleanTelephone)) {
      return res.status(400).json({ message: 'Téléphone invalide (8-15 chiffres)' });
    }
    if (!ville || !villesValides.includes(ville)) {
      return res.status(400).json({ message: 'Ville invalide' });
    }
    if (!quartier || typeof quartier !== 'string' || quartier.trim().length < 2) {
      return res.status(400).json({ message: 'Quartier invalide' });
    }
    if (!numero_cnib || typeof numero_cnib !== 'string' || !/^[A-Za-z]\d{8}$/.test(numero_cnib.trim())) {
      return res.status(400).json({ message: 'Numéro CNIB invalide (1 lettre + 8 chiffres)' });
    }
    if (!pin || !/^\d{8}$/.test(pin)) {
      return res.status(400).json({ message: 'PIN invalide (8 chiffres)' });
    }
    if (!nom_urgence || typeof nom_urgence !== 'string' || nom_urgence.trim().length < 2) {
      return res.status(400).json({ message: 'Nom du contact d\'urgence invalide' });
    }
    const cleanNumeroUrgence = normalizePhone(numero_urgence);
    if (!cleanNumeroUrgence || !/^\d{8,15}$/.test(cleanNumeroUrgence)) {
      return res.status(400).json({ message: 'Numéro d\'urgence invalide (8-15 chiffres)' });
    }
    if (!photo_profil || typeof photo_profil !== 'string' || photo_profil.trim().length < 5) {
      return res.status(400).json({ message: 'Photo de profil requise' });
    }

    const [existe] = await db.query(
      'SELECT id FROM users WHERE telephone = ?',
      [cleanTelephone]
    );
    if (existe.length > 0) {
      return res.status(400).json({ message: 'Numéro déjà utilisé' });
    }

    const pinChiffre = await bcrypt.hash(pin, 10);

    const [result] = await db.query(
      'INSERT INTO users (nom, prenom, telephone, age, ville, quartier, numero_cnib, numero_urgence, nom_urgence, photo_profil, contrat_accepte, pin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        nom.trim(),
        prenom.trim(),
        cleanTelephone,
        ageNumber,
        ville,
        quartier.trim(),
        numero_cnib.trim(),
        cleanNumeroUrgence,
        nom_urgence.trim(),
        photo_profil.trim(),
        contrat_accepte === true || contrat_accepte === 'true' ? 1 : 0,
        pinChiffre,
      ]
    );

    const token = jwt.sign(
      { userId: result.insertId, nom: `${prenom.trim()} ${nom.trim()}` },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      message: 'Compte créé avec succès',
      token,
      user: {
        id: result.insertId,
        nom: nom.trim(),
        prenom: prenom.trim(),
        telephone: cleanTelephone,
        age: ageNumber,
        ville,
        quartier: quartier.trim(),
      },
    });

  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};

// Connexion
exports.connexion = async (req, res) => {
  try {
    const { telephone, pin } = req.body;
    const cleanTelephone = normalizePhone(telephone);

    // Validations basiques
    if (!cleanTelephone || !/^\d{8,15}$/.test(cleanTelephone)) {
      return res.status(400).json({ message: 'Téléphone invalide (8-15 chiffres)' });
    }
    if (!pin || typeof pin !== 'string' || pin.length < 4) {
      return res.status(400).json({ message: 'PIN invalide' });
    }

    // Chercher l'utilisateur
    const [users] = await db.query(
      'SELECT * FROM users WHERE telephone = ?',
      [cleanTelephone]
    );
    if (users.length === 0) {
      return res.status(400).json({ message: 'Numéro introuvable' });
    }

    const user = users[0];

    // Vérifier le PIN
    const pinValide = await bcrypt.compare(pin, user.pin);
    if (!pinValide) {
      return res.status(400).json({ message: 'PIN incorrect' });
    }

    // Créer le token
    const token = jwt.sign(
      { userId: user.id, nom: user.nom },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: 'Connexion réussie',
      token,
      user: { id: user.id, nom: user.nom, telephone: user.telephone }
    });

  } catch (error) {
    res.status(500).json({ message: 'Erreur serveur', error: error.message });
  }
};
