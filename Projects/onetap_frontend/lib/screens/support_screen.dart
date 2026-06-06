import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/custom_widgets.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  void _launchWhatsApp(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ouverture de WhatsApp: +226 00 00 00 00')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Aide et Support'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('FAQ'),
          _buildFAQItem(
            'Qu\'est-ce qu\'une tontine ?',
            'Une tontine est une épargne collective où les membres cotisent régulièrement et chacun reçoit à tour de rôle la somme totale des cotisations.',
          ),
          _buildFAQItem(
            'Comment créer un groupe ?',
            'Allez dans l\'onglet "Créer un groupe", remplissez les informations requises (nom, montant, fréquence) et validez.',
          ),
          _buildFAQItem(
            'Comment rejoindre un groupe ?',
            'Obtenez un code d\'invitation d\'un créateur de groupe et entrez-le dans l\'onglet "Rejoindre un groupe".',
          ),
          _buildFAQItem(
            'Comment payer ma cotisation ?',
            'Sélectionnez votre groupe et cliquez sur "Payer". Choisissez votre opérateur mobile money et suivez les instructions.',
          ),
          _buildFAQItem(
            'Que se passe-t-il si je rate un paiement ?',
            'Un paiement en retard peut affecter votre score de réputation. Essayez de payer à temps pour maintenir un bon score.',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Contact'),
          CustomCard(
            backgroundColor: AppColors.white,
            borderRadius: 12,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone, color: Color(0xFF25D366)),
                  title: const Text('WhatsApp'),
                  subtitle: const Text('+226 00 00 00 00'),
                  onTap: () => _launchWhatsApp(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.email,
                    color: AppColors.primaryGreen,
                  ),
                  title: const Text('Email'),
                  subtitle: const Text('support@onetaptontine.bf'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('support@onetaptontine.bf')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.greyText,
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        backgroundColor: AppColors.white,
        borderRadius: 12,
        child: ExpansionTile(
          leading: const Icon(
            Icons.help_outline,
            color: AppColors.primaryGreen,
          ),
          title: Text(
            question,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            Padding(padding: const EdgeInsets.all(16.0), child: Text(answer)),
          ],
        ),
      ),
    );
  }
}
