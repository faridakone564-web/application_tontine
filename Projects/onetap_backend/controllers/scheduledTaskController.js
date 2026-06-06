const db = require('../config/db');

// Vérifier les cotisations non payées et envoyer des rappels
exports.checkUnpaidPayments = async () => {
  try {
    console.log('🔍 Vérification des cotisations non payées...');
    
    // Récupérer les groupes actifs
    const [groups] = await db.query(
      'SELECT id, nom, montant, date_demarrage FROM `groups` WHERE status = ?',
      ['active']
    );

    for (const group of groups) {
      // Calculer le nombre de cycles depuis le démarrage
      const startDate = new Date(group.date_demarrage);
      const now = new Date();
      const daysSinceStart = Math.floor((now - startDate) / (1000 * 60 * 60 * 24));
      
      if (daysSinceStart < 1) continue; // Premier jour, pas de rappel nécessaire

      // Pour chaque jour depuis le démarrage, vérifier si le paiement existe
      for (let day = 1; day <= daysSinceStart; day++) {
        const dueDate = new Date(startDate);
        dueDate.setDate(dueDate.getDate() + day);
        
        // Vérifier si un paiement existe pour ce jour
        const [payments] = await db.query(
          'SELECT p.*, u.telephone, u.nom, u.prenom FROM payments p JOIN users u ON p.user_id = u.id WHERE p.group_id = ? AND DATE(p.created_at) = ?',
          [group.id, dueDate.toISOString().split('T')[0]]
        );

        if (payments.length === 0) {
          // Aucun paiement pour ce jour, récupérer les membres
          const [members] = await db.query(
            'SELECT gm.user_id, u.telephone, u.nom, u.prenom FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = ?',
            [group.id]
          );

          for (const member of members) {
            // Vérifier si un rappel a déjà été envoyé pour ce jour
            const [existingReminder] = await db.query(
              'SELECT id FROM payment_reminders WHERE user_id = ? AND group_id = ? AND due_date = ?',
              [member.user_id, group.id, dueDate.toISOString().split('T')[0]]
            );

            if (existingReminder.length === 0) {
              // Envoyer le rappel
              await sendPaymentReminder(member, group, dueDate, day);
              
              // Enregistrer le rappel
              await db.query(
                'INSERT INTO payment_reminders (user_id, group_id, due_date, sent_at) VALUES (?, ?, ?, NOW())',
                [member.user_id, group.id, dueDate.toISOString().split('T')[0]]
              );
            }
          }
        }
      }
    }

    console.log('✅ Vérification des cotisations terminée');
  } catch (error) {
    console.error('❌ Erreur lors de la vérification des cotisations:', error);
  }
};

// Envoyer un rappel de paiement
async function sendPaymentReminder(member, group, dueDate, dayNumber) {
  try {
    // Créer une notification dans l'app
    await db.query(
      `INSERT INTO notifications (user_id, titre, message, type, lu, created_at)
       VALUES (?, ?, ?, ?, 0, NOW())`,
      [
        member.user_id,
        'Rappel de cotisation',
        `N'oubliez pas de payer votre cotisation de ${group.montant} FCFA pour le groupe "${group.nom}" (Jour ${dayNumber})`,
        'payment_reminder'
      ]
    );

    console.log(`📱 Rappel envoyé à ${member.nom} ${member.prenom} pour le groupe ${group.nom}`);
    
    // SMS integration (optionnel - à implémenter avec un service SMS)
    // await sendSMS(member.telephone, `Rappel: Cotisation de ${group.montant} FCFA pour ${group.nom}`);
  } catch (error) {
    console.error(`❌ Erreur lors de l'envoi du rappel à ${member.nom}:`, error);
  }
}
