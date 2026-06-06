import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  bool _loading = true;
  String _errorMessage = '';
  List<dynamic> _groups = [];
  List<dynamic> _filteredGroups = [];
  String _searchQuery = '';
  String _selectedMontant = 'Tous';
  String _selectedFrequence = 'Tous';

  final List<String> _montantOptions = [
    'Tous',
    'Moins de 5000',
    '5000 - 10000',
    'Plus de 10000',
  ];

  final List<String> _frequenceOptions = [
    'Tous',
    'quotidien',
    'hebdomadaire',
    'mensuel',
  ];

  @override
  void initState() {
    super.initState();
    _loadPublicGroups();
  }

  Future<void> _loadPublicGroups() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    try {
      final groups = await ApiService.getPublicGroups();
      setState(() {
        _groups = groups;
        _filteredGroups = groups;
      });
      _applyFilters();
    } catch (error) {
      setState(() {
        _errorMessage = 'Impossible de charger les tontines publiques';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = _groups.where((group) {
      final nom = (group['nom'] as String).toLowerCase();
      final organizer = (group['organizerName'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      final textMatch = query.isEmpty || nom.contains(query) || organizer.contains(query);

      bool montantMatch = true;
      final montant = (group['montant'] as num).toDouble();
      if (_selectedMontant == 'Moins de 5000') {
        montantMatch = montant < 5000;
      } else if (_selectedMontant == '5000 - 10000') {
        montantMatch = montant >= 5000 && montant <= 10000;
      } else if (_selectedMontant == 'Plus de 10000') {
        montantMatch = montant > 10000;
      }

      bool frequenceMatch = true;
      if (_selectedFrequence != 'Tous') {
        frequenceMatch = (group['frequence'] as String).toLowerCase() == _selectedFrequence.toLowerCase();
      }

      return textMatch && montantMatch && frequenceMatch;
    }).toList();

    setState(() {
      _filteredGroups = filtered;
    });
  }

  Future<void> _demanderRejoindre(Map<String, dynamic> group) async {
    if (group['codeInvitation'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de demander l\'adhésion sans code d\'invitation.')),
      );
      return;
    }

    try {
      final response = await ApiService.rejoindreGroupe(codeInvitation: group['codeInvitation'] as String);
      if (response['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'])));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande d\'adhésion envoyée.')));
      }
      await _loadPublicGroups();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${error.toString()}')),
      );
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    if (status == 'recrutement') {
      color = const Color(0xFFFFA726);
    } else if (status == 'active') {
      color = AppColors.primaryGreen;
    } else {
      color = Colors.grey;
    }
    final label = status == 'recrutement'
        ? 'En recrutement'
        : status == 'active'
            ? 'Active'
            : 'Terminée';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return CustomCard(
      backgroundColor: AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  group['nom'] as String? ?? 'Tontine',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _buildStatusBadge(group['status'] as String? ?? 'recrutement'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${(group['montant'] as num).toStringAsFixed(0)} FCFA · ${group['frequence']}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.greyText, size: 18),
              const SizedBox(width: 6),
              Text(
                '${group['currentMembers'] ?? 0} / ${group['maxMembres'] ?? 0} membres',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${group['placesRestantes'] ?? 0} places restantes',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            minHeight: 8,
            value: (group['maxMembres'] as int? ?? 1) > 0
                ? (group['currentMembers'] as int? ?? 0) / (group['maxMembres'] as int? ?? 1)
                : 0,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organisateur',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group['organizerName'] as String? ?? 'Inconnu',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      '${group['organizerScore'] ?? 100}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: group['status'] == 'recrutement'
                  ? () => _demanderRejoindre(group)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Demander à rejoindre'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Découvrir'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Rechercher une tontine ou un organisateur',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _applyFilters();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMontant,
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: AppColors.white,
                          ),
                          items: _montantOptions
                              .map((option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(option),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _selectedMontant = value;
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFrequence,
                          decoration: const InputDecoration(
                            labelText: 'Fréquence',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            filled: true,
                            fillColor: AppColors.white,
                          ),
                          items: _frequenceOptions
                              .map((option) => DropdownMenuItem(
                                    value: option,
                                    child: Text(option[0].toUpperCase() + option.substring(1)),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            _selectedFrequence = value;
                            _applyFilters();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _errorMessage.isNotEmpty
                        ? Center(child: Text(_errorMessage))
                        : _filteredGroups.isEmpty
                            ? const Center(child: Text('Aucune tontine trouvée'))
                            : ListView.separated(
                                itemCount: _filteredGroups.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildGroupCard(_filteredGroups[index] as Map<String, dynamic>);
                                },
                              ),
                  ),
                ],
              ),
            ),
    );
  }
}
