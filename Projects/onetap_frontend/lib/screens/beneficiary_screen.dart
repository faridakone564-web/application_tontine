import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class BeneficiaryScreen extends StatefulWidget {
  const BeneficiaryScreen({super.key});

  @override
  State<BeneficiaryScreen> createState() => _BeneficiaryScreenState();
}

class _BeneficiaryScreenState extends State<BeneficiaryScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _mesGroupes = [];
  Map<int, List<dynamic>> _beneficiairesParGroupe = {};

  @override
  void initState() {
    super.initState();
    _loadBeneficiaires();
  }

  Future<void> _loadBeneficiaires() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = await ApiService.getUserId();
      if (userId == null) {
        setState(() {
          _errorMessage = 'Utilisateur non connecté';
        });
        return;
      }

      final groupes = await ApiService.getMesGroupes(userId);
      final beneficiairesMap = <int, List<dynamic>>{};

      for (final groupe in groupes) {
        try {
          final beneficiaires =
              await ApiService.getBeneficiairesGroupe(groupe['id'] as int);
          beneficiairesMap[groupe['id'] as int] = beneficiaires;
        } catch (e) {
          // Silently skip if endpoint not available
        }
      }

      setState(() {
        _mesGroupes = groupes;
        _beneficiairesParGroupe = beneficiairesMap;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Impossible de charger les bénéficiaires';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                    'Mes Bénéficiaires',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contactez vos bénéficiaires par groupe',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.greyText,
                        ),
                  ),
                ],
              ),
            ),

            // Barre de recherche
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un contact...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Liste des bénéficiaires par groupe
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentOrange,
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        )
                      : _mesGroupes.isEmpty
                          ? Center(
                              child: Text(
                                'Aucun groupe trouvé',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : ListView.separated(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _mesGroupes.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 24),
                              itemBuilder: (context, index) {
                                final groupe = _mesGroupes[index];
                                final groupeId = groupe['id'] as int;
                                final beneficiaires =
                                    _beneficiairesParGroupe[groupeId] ?? [];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      groupe['nom'] as String? ??
                                          'Groupe sans nom',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 12),
                                    if (beneficiaires.isEmpty)
                                      CustomCard(
                                        backgroundColor: AppColors.white,
                                        child: Text(
                                          'Aucun bénéficiaire',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: beneficiaires.length,
                                        separatorBuilder: (context, idx) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, idx) {
                                          final beneficiaire =
                                              beneficiaires[idx];
                                          final ordre =
                                              beneficiaire['ordre'] ?? 0;
                                          final isCurrent = idx == 0;

                                          return BeneficiaryCard(
                                            name: beneficiaire['nom'] ??
                                                'N/A',
                                            phone: beneficiaire['telephone'] ??
                                                'N/A',
                                            tourNumber: ordre,
                                            dateEntree:
                                                beneficiaire['dateEntree'],
                                            isCurrent: isCurrent,
                                          );
                                        },
                                      ),
                                  ],
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

class BeneficiaryCard extends StatelessWidget {
  final String name;
  final String phone;
  final int tourNumber;
  final String? dateEntree;
  final bool isCurrent;

  const BeneficiaryCard({
    super.key,
    required this.name,
    required this.phone,
    required this.tourNumber,
    this.dateEntree,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = dateEntree != null
        ? DateTime.parse(dateEntree!).toString().split(' ')[0]
        : 'Date inconnue';

    return CustomCard(
      backgroundColor: isCurrent
          ? AppColors.accentOrange.withAlpha(26)
          : AppColors.white,
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.accentOrange.withAlpha(51)
                  : AppColors.lightGreenBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tour',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                      ),
                ),
                Text(
                  '$tourNumber',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? AppColors.accentOrange
                        : AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'En cours',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  phone,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Depuis $dateStr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.greyText,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.message),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Message à $name'),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.phone),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Appel à $name'),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
