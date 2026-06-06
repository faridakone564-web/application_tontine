import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class MesPaiementsScreen extends StatefulWidget {
  const MesPaiementsScreen({super.key});

  @override
  State<MesPaiementsScreen> createState() => _MesPaiementsScreenState();
}

class _MesPaiementsScreenState extends State<MesPaiementsScreen> {
  bool _isLoading = true;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final userId = await ApiService.getUserId();
      if (userId != null) {
        print('Chargement des paiements pour userId: $userId');
        final payments = await ApiService.getUserPayments(userId);
        print('Paiements récupérés: ${payments.length}');
        setState(() => _payments = payments);
      } else {
        print('userId est null');
      }
    } catch (error) {
      print('Erreur lors du chargement des paiements: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $error')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String statut) {
    switch (statut.toUpperCase()) {
      case 'VALIDEE':
        return const Color(0xFF4CAF50);
      case 'PENDING':
      case 'EN_ATTENTE':
        return const Color(0xFFFF9800);
      case 'REJETE':
      case 'ECHOUE':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Mes Paiements'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : _payments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: AppColors.greyText),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun paiement pour le moment',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _payments.length,
              itemBuilder: (context, index) {
                final payment = _payments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CustomCard(
                    backgroundColor: AppColors.white,
                    borderRadius: 12,
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            payment['statut'] ?? 'PENDING',
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.payment,
                          color: _getStatusColor(
                            payment['statut'] ?? 'PENDING',
                          ),
                        ),
                      ),
                      title: Text(
                        payment['group_name'] ?? 'Groupe inconnu',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${payment['montant'] ?? 0} FCFA'),
                          Text(
                            payment['created_at'] ?? '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            payment['statut'] ?? 'PENDING',
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          payment['statut'] ?? 'PENDING',
                          style: TextStyle(
                            color: _getStatusColor(
                              payment['statut'] ?? 'PENDING',
                            ),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
