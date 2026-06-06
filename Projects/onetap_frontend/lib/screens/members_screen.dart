import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class MembersScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final bool isGroupOwner;

  const MembersScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isGroupOwner,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _activeMembers = [];
  List<dynamic> _pendingMembers = [];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final members = await ApiService.getGroupMembers(widget.groupId);
      final activeMembers =
          members.where((m) => m['ordre'] != null).toList();
      activeMembers.sort((a, b) => (a['ordre'] as int).compareTo(b['ordre'] as int));

      List<dynamic> pendingMembers = [];
      if (widget.isGroupOwner) {
        try {
          pendingMembers =
              await ApiService.getMembresEnAttente(widget.groupId);
        } catch (e) {
          // Silently fail if endpoint not available
        }
      }

      if (!mounted) return;
      setState(() {
        _activeMembers = activeMembers;
        _pendingMembers = pendingMembers;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Impossible de charger les membres';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _approveMember(int memberId) async {
    try {
      await ApiService.approuverMembre(memberId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre approuvé')),
      );
      _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${error.toString()}')),
      );
    }
  }

  Future<void> _rejectMember(int memberId) async {
    try {
      await ApiService.rejeterMembre(memberId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre rejeté')),
      );
      _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Membres du Groupe'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
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
                        fontSize: 16,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Membres en attente (seulement pour le créateur)
                      if (widget.isGroupOwner && _pendingMembers.isNotEmpty) ...[
                        SectionHeader(
                          title: 'En attente d\'approbation (${_pendingMembers.length})',
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingMembers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final member = _pendingMembers[index];
                            return CustomCard(
                              backgroundColor: Colors.orange.shade50,
                              borderRadius: 12,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            AppColors.accentOrange.withAlpha(51),
                                        child: Text(
                                          member['nom'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.accentOrange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  member['nom'] ?? 'N/A',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accentOrange,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'En attente',
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
                                              member['telephone'] ?? 'N/A',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                            _rejectMember(member['memberId']),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Rejeter'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFFD32F2F),
                                          side: const BorderSide(
                                            color: Color(0xFFD32F2F),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _approveMember(member['memberId']),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approuver'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Membres actifs
                      SectionHeader(
                        title: 'Membres Actifs (${_activeMembers.length})',
                      ),
                      const SizedBox(height: 12),
                      if (_activeMembers.isEmpty)
                        CustomCard(
                          backgroundColor: AppColors.white,
                          child: Text(
                            'Aucun membre actif pour le moment',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _activeMembers.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final member = _activeMembers[index];
                            final ordre = member['ordre'] ?? 0;
                            return CustomCard(
                              backgroundColor: AppColors.white,
                              borderRadius: 12,
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGreenBg,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Tour',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        Text(
                                          '$ordre',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['nom'] ?? 'N/A',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        Text(
                                          member['telephone'] ?? 'N/A',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        if (member['joinedAt'] != null)
                                          Text(
                                            'Depuis ${DateTime.parse(member['joinedAt'] as String).toString().split(' ')[0]}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.greyText,
                                                ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }
}
