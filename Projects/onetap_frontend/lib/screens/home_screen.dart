import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import '../models/group_model.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';
import 'mes_groups_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  int _groupCount = 0;
  double _totalCotise = 0;
  List<GroupModel> _groupes = [];
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null) {
        throw Exception('Utilisateur non identifié');
      }

      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('user_name') ?? 'Utilisateur';

      final groupesData = await ApiService.getMesGroupes(userId);
      final totalData = await ApiService.getTotalCotisations(userId);

      final groupes = groupesData
          .map((item) => GroupModel.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _groupes = groupes;
        _groupCount = groupes.where((groupe) => groupe.isActive).length;
        _totalCotise = (totalData['total'] is num)
            ? (totalData['total'] as num).toDouble()
            : double.tryParse(totalData['total']?.toString() ?? '0') ?? 0;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().contains('Exception:')
            ? error.toString().replaceFirst('Exception:', '').trim()
            : 'Impossible de charger les données';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _userName?.split(' ').first ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : SingleChildScrollView(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête de bienvenue
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, $firstName',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gérez vos tontines facilement',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.greyText),
                          ),
                        ],
                      ),
                    ),

                    // Carte de solde avec graphique
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GroupStatusCard(
                        groupName: 'Total Cotisé',
                        totalMembers: _groupCount,
                        contributionAmount:
                            '${_totalCotise.toStringAsFixed(0)} FCFA',
                        nextBeneficiary: 'Voir les détails',
                        progressValue: (_groupCount / 10).clamp(0.0, 1.0),
                        currentCycle: 1,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Boutons rapides
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Actions Rapides',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ActionButton(
                                  label: 'Créer\nGROUPE',
                                  icon: Icons.add_circle_outline,
                                  isPrimary: true,
                                  onPressed: () {
                                    Navigator.of(context)
                                        .push(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CreateGroupScreen(),
                                          ),
                                        )
                                        .then((_) => _loadDashboard());
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ActionButton(
                                  label: 'Mes\nGROUPES',
                                  icon: Icons.group,
                                  isPrimary: true,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const MesGroupsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ActionButton(
                                  label: 'Invita-\nTIONS',
                                  icon: Icons.mail,
                                  isPrimary: true,
                                  onPressed: () {
                                    // TODO: Ouvrir les invitations
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Activité récente
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SectionHeader(
                        title: 'Mes Groupes',
                        onSeeAll: _groupes.length > 3
                            ? () {
                                // TODO: Afficher tous les groupes
                              }
                            : null,
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CustomCard(
                          backgroundColor: const Color(0xFFFFEBEE),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFD32F2F)),
                          ),
                        ),
                      )
                    else if (_groupes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CustomCard(
                          backgroundColor: AppColors.white,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.group_add,
                                size: 48,
                                color: AppColors.greyText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Pas encore de groupe',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              ActionButton(
                                label: 'Rejoindre un Groupe',
                                icon: Icons.group_add,
                                onPressed: () {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const JoinGroupScreen(),
                                        ),
                                      )
                                      .then((_) => _loadDashboard());
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _groupes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final groupe = _groupes[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GroupDetailScreen(
                                      groupId: groupe.id,
                                      groupName: groupe.nom,
                                      montant: groupe.montant,
                                      frequence: groupe.frequence,
                                    ),
                                  ),
                                );
                              },
                              child: CustomCard(
                                backgroundColor: AppColors.white,
                                borderRadius: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                groupe.nom,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.headlineSmall,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${groupe.montant.toStringAsFixed(0)} FCFA · ${groupe.frequence}',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        _buildStatusBadge(groupe.status),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Prochain bénéficiaire : ${groupe.prochainBeneficiaire != null ? groupe.prochainBeneficiaire!.nom : 'Non défini'}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
    String displayStatus;
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'recrutement':
        displayStatus = 'En recrutement';
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFEF6C00);
        break;
      case 'active':
        displayStatus = 'Active';
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'terminée':
      case 'terminee':
        displayStatus = 'Terminée';
        backgroundColor = const Color(0xFFE0E0E0);
        textColor = const Color(0xFF616161);
        break;
      default:
        displayStatus = status;
        backgroundColor = const Color(0xFFF3E5F5);
        textColor = AppColors.groupPurple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
