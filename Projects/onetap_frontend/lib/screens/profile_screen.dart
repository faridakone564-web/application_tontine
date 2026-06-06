import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'login_screen.dart';
import 'mes_paiements_screen.dart';
import 'mes_gains_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String _name = '';
  String _prenom = '';
  String _telephone = '';
  String _ville = '';
  String _quartier = '';
  String _photoProfil = '';
  int _groupCount = 0;
  double _totalCotise = 0.0;
  int _score = 100;
  String _niveau = 'Débutant';
  Color _niveauColor = Colors.red;
  int _paiementsATemps = 0;
  int _paiementsEnRetard = 0;
  int _tontinesTerminees = 0;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final userId = await ApiService.getUserId();
      if (userId == null) throw Exception('Utilisateur non identifié');

      final profile = await ApiService.getUserProfile(userId);
      final groupes = await ApiService.getMesGroupes(userId);
      final totalData = await ApiService.getTotalCotisations(userId);

      // Check if user is a creator (owns at least one group)
      final isCreator = groupes.any((g) => g['isOwner'] == true);

      // Charger la réputation
      try {
        final reputation = await ApiService.getUserReputation(userId);
        setState(() {
          _score = reputation['score'] ?? 100;
          _niveau = reputation['niveau'] ?? 'Débutant';
          _paiementsATemps = reputation['paiementsATemps'] ?? 0;
          _paiementsEnRetard = reputation['paiementsEnRetard'] ?? 0;
          _tontinesTerminees = reputation['tontinesTerminees'] ?? 0;
          _niveauColor = _getNiveauColor(_niveau);
        });
      } catch (_) {}

      setState(() {
        _name = profile['nom'] ?? '';
        _prenom = profile['prenom'] ?? '';
        _telephone = profile['telephone'] ?? '';
        _ville = profile['ville'] ?? '';
        _quartier = profile['quartier'] ?? '';
        _photoProfil = profile['photo_profil'] ?? '';
        _groupCount = groupes.length;
        _totalCotise = (totalData['total'] as num?)?.toDouble() ?? 0.0;
        _isCreator = isCreator;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement du profil: $error')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _getNiveauColor(String niveau) {
    switch (niveau) {
      case 'Exemplaire':
        return const Color(0xFF2E7D32);
      case 'Fiable':
        return const Color(0xFF7CB342);
      case 'Régulier':
        return const Color(0xFFFF9800);
      default:
        return Colors.red;
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD32F2F),
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _editProfile() async {
    final nomController = TextEditingController(text: _name);
    final prenomController = TextEditingController(text: _prenom);
    final villeController = TextEditingController(text: _ville);
    final quartierController = TextEditingController(text: _quartier);

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le Profil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              TextField(
                controller: prenomController,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              TextField(
                controller: villeController,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              TextField(
                controller: quartierController,
                decoration: const InputDecoration(labelText: 'Quartier'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final userId = await ApiService.getUserId();
        if (userId != null) {
          await ApiService.updateUserProfile(
            userId: userId,
            nom: nomController.text.trim(),
            prenom: prenomController.text.trim(),
            telephone: _telephone,
            ville: villeController.text.trim(),
            quartier: quartierController.text.trim(),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
          _loadProfile();
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
      }
    }
  }

  VoidCallback _showNotImplemented(String feature) {
    return () {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$feature - Fonctionnalité bientôt disponible')),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Profil',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),

                    // Carte profil
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CustomCard(
                        backgroundColor: AppColors.white,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _showNotImplemented('Changer photo'),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.primaryGreen,
                                backgroundImage: _photoProfil.isNotEmpty
                                    ? NetworkImage(_photoProfil)
                                    : null,
                                child: _photoProfil.isEmpty
                                    ? Text(
                                        _name.isNotEmpty
                                            ? _name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_prenom} ${_name}'.trim(),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _telephone,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.greyText),
                            ),
                            if (_ville.isNotEmpty || _quartier.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${_ville.isNotEmpty ? _ville : ''}${_ville.isNotEmpty && _quartier.isNotEmpty ? ', ' : ''}${_quartier.isNotEmpty ? _quartier : ''}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.greyText),
                                ),
                              ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _niveauColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_niveau == 'Exemplaire')
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFFD700),
                                      size: 16,
                                    ),
                                  if (_niveau == 'Exemplaire')
                                    const SizedBox(width: 4),
                                  Text(
                                    _niveau,
                                    style: TextStyle(
                                      color: _niveauColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Score de réputation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CustomCard(
                        backgroundColor: AppColors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Score de Réputation',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _niveauColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _niveau,
                                    style: TextStyle(
                                      color: _niveauColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  '$_score',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: _niveauColor,
                                  ),
                                ),
                                const Text(
                                  ' / 500',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: _score / 500,
                                minHeight: 12,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _niveauColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildReputationStat(
                                  'À temps',
                                  '$_paiementsATemps',
                                  Icons.check_circle,
                                  const Color(0xFF4CAF50),
                                ),
                                _buildReputationStat(
                                  'En retard',
                                  '$_paiementsEnRetard',
                                  Icons.warning,
                                  Colors.orange,
                                ),
                                _buildReputationStat(
                                  'Terminées',
                                  '$_tontinesTerminees',
                                  Icons.emoji_events,
                                  const Color(0xFF2E7D32),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statistiques
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: CustomCard(
                              backgroundColor: AppColors.white,
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.group,
                                    color: AppColors.primaryGreen,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _groupCount.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.primaryGreen,
                                        ),
                                  ),
                                  Text(
                                    'Groupes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomCard(
                              backgroundColor: AppColors.white,
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.savings,
                                    color: AppColors.accentOrange,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_totalCotise.toStringAsFixed(0)} F',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.accentOrange,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    'Cotisé',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomCard(
                              backgroundColor: AppColors.white,
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Color(0xFFFFD700),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _tontinesTerminees.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: const Color(0xFFFFD700),
                                        ),
                                  ),
                                  Text(
                                    'Terminées',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _buildOptionTile(
                            'Modifier le Profil',
                            Icons.edit,
                            _editProfile,
                          ),
                          const SizedBox(height: 12),
                          _buildOptionTile(
                            'Mes Paiements',
                            Icons.receipt_long,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MesPaiementsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_isCreator)
                            _buildOptionTile(
                              'Mes Gains',
                              Icons.account_balance_wallet,
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MesGainsScreen(),
                                ),
                              ),
                            ),
                          if (_isCreator) const SizedBox(height: 12),
                          _buildOptionTile(
                            'Notifications',
                            Icons.notifications,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOptionTile(
                            'Paramètres',
                            Icons.settings,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOptionTile(
                            'Aide et Support',
                            Icons.help_outline,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SupportScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ActionButton(
                        label: 'Déconnexion',
                        icon: Icons.logout,
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReputationStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildOptionTile(String label, IconData icon, VoidCallback onTap) {
    return CustomCard(
      backgroundColor: AppColors.white,
      borderRadius: 12,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(label),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.greyText,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }
}
