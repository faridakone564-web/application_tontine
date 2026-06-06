import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../models/group_model.dart';
import '../widgets/custom_widgets.dart';
import 'group_detail_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';

class MesGroupsScreen extends StatefulWidget {
  const MesGroupsScreen({super.key});

  @override
  State<MesGroupsScreen> createState() => _MesGroupsScreenState();
}

class _MesGroupsScreenState extends State<MesGroupsScreen> {
  bool _isLoading = true;
  List<GroupModel> _groupes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadGroupes();
  }

  Future<void> _loadGroupes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final userId = await ApiService.getUserId();
      if (userId == null) throw Exception('Utilisateur non identifié');
      final data = await ApiService.getMesGroupes(userId);
      final groupes = data
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _groupes = groupes;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des groupes';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Groupes',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_groupes.length} groupe(s) actif(s)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.greyText,
                        ),
                  ),
                ],
              ),
            ),

            // Boutons d'action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ActionButton(
                      label: 'Créer Groupe',
                      icon: Icons.add,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateGroupScreen(),
                          ),
                        ).then((_) => _loadGroupes());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ActionButton(
                      label: 'Rejoindre',
                      icon: Icons.group_add,
                      isPrimary: false,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinGroupScreen(),
                          ),
                        ).then((_) => _loadGroupes());
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Contenu principal
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentOrange,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFD32F2F),
                              ),
                            ),
                          ),
                        )
                      : _groupes.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16),
                              child: CustomCard(
                                backgroundColor: AppColors.white,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.group_add,
                                      size: 48,
                                      color: AppColors.greyText,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Aucun groupe',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Créez ou rejoignez un groupe pour commencer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.greyText,
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _groupes.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final groupe = _groupes[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          groupe.nom,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .headlineSmall,
                                                        ),
                                                      ),
                                                      if (groupe.isLocked)
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFFFEBEE),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: const Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons.lock,
                                                                size: 14,
                                                                color: Color(
                                                                    0xFFD32F2F),
                                                              ),
                                                              SizedBox(
                                                                  width: 4),
                                                              Text(
                                                                'Verrouillée',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  color: Color(
                                                                      0xFFD32F2F),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      if (groupe.isFull)
                                                        Container(
                                                          padding: const EdgeInsets
                                                              .symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          margin: const EdgeInsets
                                                              .only(left: 8),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFFFFEBEE),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                          ),
                                                          child: const Text(
                                                            'COMPLET',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Color(
                                                                  0xFFD32F2F),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '${groupe.montant.toStringAsFixed(0)} FCFA · ${groupe.frequence}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  // Barre de progression et info places
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Text(
                                                            '👥 ${groupe.currentMembers}/${groupe.maxMembers} membres',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          Text(
                                                            '✅ ${groupe.availableSlots} places',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color:
                                                                      AppColors
                                                                          .primaryGreen,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(
                                                          height: 8),
                                                      // Barre de progression
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child:
                                                            LinearProgressIndicator(
                                                          minHeight: 6,
                                                          value: groupe
                                                                  .maxMembers >
                                                              0
                                                              ? groupe
                                                                      .currentMembers /
                                                                  groupe
                                                                      .maxMembers
                                                              : 0,
                                                          backgroundColor:
                                                              const Color(
                                                                  0xFFE0E0E0),
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            groupe.isFull
                                                                ? const Color(
                                                                    0xFFD32F2F)
                                                                : AppColors
                                                                    .primaryGreen,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: groupe.status ==
                                                        'active'
                                                    ? AppColors.accentOrange
                                                    : AppColors.primaryGreen,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                groupe.status == 'active'
                                                    ? 'Active'
                                                    : 'En attente',
                                                style: const TextStyle(
                                                  color: AppColors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
