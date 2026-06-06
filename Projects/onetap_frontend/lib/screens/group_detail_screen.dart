import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';
import 'payment_screen.dart';
import 'members_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final int groupId;
  final String groupName;
  final double montant;
  final String frequence;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.montant,
    required this.frequence,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _groupDetails;
  List<dynamic> _members = [];
  List<dynamic> _payments = [];
  List<dynamic> _pendingMembers = [];
  bool _isGroupOwner = false;
  double _totalCommissions = 0;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  Future<void> _loadGroupDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final details = await ApiService.getGroupDetails(widget.groupId);
      final members = await ApiService.getGroupMembers(widget.groupId);
      final payments = await ApiService.getGroupPayments(widget.groupId);

      _isGroupOwner = details['isOwner'] == true;

      List<dynamic> pendingMembers = [];
      if (_isGroupOwner) {
        try {
          pendingMembers = await ApiService.getMembresEnAttente(widget.groupId);
        } catch (e) {
          // Silently fail if endpoint not available
        }
      }

      // Load commissions for group owner
      double totalCommissions = 0;
      if (_isGroupOwner) {
        try {
          final userId = await ApiService.getUserId();
          if (userId != null) {
            final commissions = await ApiService.getCommissionsCreateur(userId);
            totalCommissions =
                (commissions['total_commissions'] as num?)?.toDouble() ?? 0;
          }
        } catch (e) {
          // Silently fail if endpoint not available
        }
      }

      setState(() {
        _groupDetails = details;
        _members = members;
        _payments = payments;
        _pendingMembers = pendingMembers;
        _totalCommissions = totalCommissions;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Impossible de charger les détails du groupe';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupName = _groupDetails?['nom'] as String? ?? widget.groupName;
    final montant =
        (_groupDetails?['montant'] as num?)?.toDouble() ?? widget.montant;
    final frequence =
        _groupDetails?['frequence'] as String? ?? widget.frequence;
    final invitationCode = _groupDetails?['codeInvitation'] as String? ?? '';
    final prochainBeneficiaire =
        _groupDetails?['prochainBeneficiaire'] as Map<String, dynamic>?;
    final status = _groupDetails?['status'] as String? ?? 'en_attente';
    final isLocked = status == 'active';
    final currentMembers = _groupDetails?['currentMembers'] as int? ?? 0;
    final maxMembers = _groupDetails?['maxMembres'] as int? ?? 10;
    final availableSlots = _groupDetails?['availableSlots'] as int? ?? 0;
    final isFull = availableSlots <= 0;
    final startDate = _groupDetails?['startDate'] as String?;

    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Détails du Groupe'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
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
                  // Badge de statut
                  _buildStatusBadge(status),
                  const SizedBox(height: 16),

                  // Mes gains (pour le créateur)
                  if (_isGroupOwner)
                    CustomCard(
                      backgroundColor: AppColors.white,
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: AppColors.accentOrange,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mes gains',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_totalCommissions.toStringAsFixed(0)} FCFA',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppColors.accentOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isGroupOwner) const SizedBox(height: 16),

                  // Carte du groupe
                  GroupStatusCard(
                    groupName: groupName,
                    totalMembers: _members.length,
                    contributionAmount: '${montant.toStringAsFixed(0)} FCFA',
                    nextBeneficiary:
                        prochainBeneficiaire?['nom'] ?? 'Non défini',
                    progressValue: 0.5,
                    currentCycle: 1,
                  ),
                  const SizedBox(height: 20),

                  // Affichage du statut et des places disponibles
                  if (isLocked)
                    CustomCard(
                      backgroundColor: const Color(0xFFFFEBEE),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCDD2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tontine verrouillée',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFFD32F2F),
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Cette tontine a déjà démarré. Les inscriptions sont fermées.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (startDate != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Démarrée le: ${DateTime.tryParse(startDate)?.toString().split(' ')[0] ?? startDate}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!isLocked)
                    CustomCard(
                      backgroundColor: AppColors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '👥 Membres et Places',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (isFull)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'COMPLET',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFD32F2F),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Membres actuels',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$currentMembers / $maxMembers',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Places disponibles',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$availableSlots',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          color: isFull
                                              ? const Color(0xFFD32F2F)
                                              : AppColors.accentOrange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Barre de progression
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 8,
                              value: maxMembers > 0
                                  ? currentMembers / maxMembers
                                  : 0,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isFull
                                    ? const Color(0xFFD32F2F)
                                    : AppColors.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Prochain bénéficiaire mis en évidence
                  CustomCard(
                    backgroundColor: AppColors.groupPurpleLight,
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.groupPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star, color: AppColors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Prochain bénéficiaire',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.groupPurple,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                prochainBeneficiaire?['nom'] ??
                                    'Aucun bénéficiaire défini',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: AppColors.darkText),
                              ),
                              if (prochainBeneficiaire?['telephone'] != null)
                                Text(
                                  prochainBeneficiaire!['telephone'],
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Code d'invitation
                  if (invitationCode.isNotEmpty) ...[
                    CustomCard(
                      backgroundColor: AppColors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Code d\'invitation',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.groupPurpleLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  invitationCode,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.groupPurple,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: AppColors.groupPurple,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Code copié!'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Infos du groupe
                  SectionHeader(title: 'Informations'),
                  const SizedBox(height: 12),
                  CustomCard(
                    backgroundColor: AppColors.white,
                    child: Column(
                      children: [
                        _buildInfoRow(
                          'Fréquence',
                          frequence,
                          Icons.calendar_today,
                        ),
                        Divider(color: AppColors.borderGrey),
                        _buildInfoRow(
                          'Montant',
                          '${montant.toStringAsFixed(0)} FCFA',
                          Icons.attach_money,
                        ),
                        Divider(color: AppColors.borderGrey),
                        _buildInfoRow(
                          'Membres',
                          '${_members.length}',
                          Icons.people,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Membres
                  SectionHeader(title: 'Membres du Groupe'),
                  const SizedBox(height: 12),
                  if (_members.isEmpty)
                    CustomCard(
                      backgroundColor: AppColors.white,
                      child: Text(
                        'Aucun membre pour le moment',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _members.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return CustomCard(
                          backgroundColor: AppColors.white,
                          borderRadius: 12,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.lightGreenBg,
                                child: Text(
                                  member['nom'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                            member['nom'] ?? 'N/A',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                        ),
                                        if ((member['ordre'] as int?) != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.accentOrange,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'Tour ${member['ordre']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      member['telephone'] ?? 'N/A',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  // Paiements du groupe
                  SectionHeader(title: 'Paiements du groupe'),
                  const SizedBox(height: 12),
                  if (_payments.isEmpty)
                    CustomCard(
                      backgroundColor: AppColors.white,
                      child: Text(
                        'Aucun paiement enregistré pour ce groupe.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _payments.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final payment = _payments[index];
                        final String statut =
                            payment['statut']?.toString() ?? 'N/A';
                        return CustomCard(
                          backgroundColor: AppColors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${payment['payerNom'] ?? 'Utilisateur'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  _buildStatusChip(statut),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${payment['montant']?.toStringAsFixed(0) ?? '0'} FCFA',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                payment['createdAt']?.toString() ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),

                  // Boutons d'action
                  if (isFull)
                    CustomCard(
                      backgroundColor: const Color(0xFFFFEBEE),
                      child: Center(
                        child: Text(
                          '🚫 Ce groupe est complet. Impossible de rejoindre.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  if (isLocked)
                    CustomCard(
                      backgroundColor: const Color(0xFFFFEBEE),
                      child: Center(
                        child: Text(
                          'Cette tontine a déjà démarré. Les actions sont limitées.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: const Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ),
                  // Bouton Démarrer la Tontine (seulement pour le créateur quand status = recrutement)
                  if (_isGroupOwner && status == 'recrutement')
                    ActionButton(
                      label: 'Démarrer la Tontine',
                      icon: Icons.play_arrow,
                      onPressed: () async {
                        try {
                          await ApiService.demarrerGroupe(widget.groupId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tontine démarrée avec succès'),
                            ),
                          );
                          _loadGroupDetails();
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur: ${error.toString()}'),
                            ),
                          );
                        }
                      },
                    ),
                  if (!isLocked) ...[
                    ActionButton(
                      label: 'Payer ma cotisation',
                      icon: Icons.payment,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              groupId: widget.groupId,
                              groupName: groupName,
                              montantGroupe: montant,
                              reference: 'GROUP-${widget.groupId}',
                            ),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    ActionButton(
                      label: 'Payer ma cotisation',
                      icon: Icons.payment,
                      isLoading: false,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              groupId: widget.groupId,
                              groupName: groupName,
                              montantGroupe: montant,
                              reference: 'GROUP-${widget.groupId}',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      ActionButton(
                        label: 'Voir les Membres',
                        icon: Icons.group,
                        isPrimary: false,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MembersScreen(
                                groupId: widget.groupId,
                                groupName: groupName,
                                isGroupOwner: _isGroupOwner,
                              ),
                            ),
                          );
                        },
                      ),
                      if (_isGroupOwner && _pendingMembers.isNotEmpty)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_pendingMembers.length}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayStatus.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final lower = status.toLowerCase();
    final Color backgroundColor;
    final Color textColor;

    if (lower.contains('valid') ||
        lower.contains('done') ||
        lower.contains('paid') ||
        lower.contains('success')) {
      backgroundColor = const Color(0xFFE8F5E9);
      textColor = const Color(0xFF2E7D32);
    } else if (lower.contains('pending') || lower.contains('attente')) {
      backgroundColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFEF6C00);
    } else {
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
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
