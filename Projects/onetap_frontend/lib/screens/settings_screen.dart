import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/custom_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Sécurité'),
          _buildSettingTile(
            'Changer le PIN',
            Icons.lock,
            () => _showChangePinDialog(context),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Langue'),
          _buildSettingTile(
            'Français',
            Icons.language,
            () {},
            trailing: 'Actif',
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('À propos'),
          _buildSettingTile(
            'Version de l\'application',
            Icons.info,
            () {},
            trailing: '1.0.0',
          ),
          _buildSettingTile(
            'Politique de confidentialité',
            Icons.privacy_tip,
            () => _showPrivacyPolicy(context),
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

  Widget _buildSettingTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    String? trailing,
  }) {
    return CustomCard(
      backgroundColor: AppColors.white,
      borderRadius: 12,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(title),
        trailing: trailing != null
            ? Text(
                trailing,
                style: const TextStyle(
                  color: AppColors.greyText,
                  fontSize: 12,
                ),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.greyText,
              ),
        onTap: onTap,
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              decoration: const InputDecoration(labelText: 'Ancien PIN'),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(labelText: 'Nouveau PIN'),
              obscureText: true,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN modifié avec succès')),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Politique de confidentialité'),
        content: const SingleChildScrollView(
          child: Text(
            'OneTap Tontine s\'engage à protéger vos données personnelles.\n\n'
            'Nous collectons uniquement les informations nécessaires au fonctionnement de l\'application :\n'
            '- Nom et prénom\n'
            '- Numéro de téléphone\n'
            '- Informations de paiement\n\n'
            'Vos données ne sont jamais partagées avec des tiers sans votre consentement.\n\n'
            'Vous pouvez demander la suppression de vos données à tout moment.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
