const jwt = require('jsonwebtoken');
require('dotenv').config();

module.exports = (req, res, next) => {
	const authHeader = req.headers['authorization'] || req.headers['Authorization'];
	if (!authHeader) return res.status(401).json({ message: 'Token manquant' });

	const parts = authHeader.split(' ');
	if (parts.length !== 2 || parts[0] !== 'Bearer') {
		return res.status(401).json({ message: 'Format d\'autorisation invalide' });
	}

	const token = parts[1];
	try {
		const payload = jwt.verify(token, process.env.JWT_SECRET);
		req.user = payload;
		next();
	} catch (err) {
		return res.status(401).json({ message: 'Token invalide' });
	}
};

