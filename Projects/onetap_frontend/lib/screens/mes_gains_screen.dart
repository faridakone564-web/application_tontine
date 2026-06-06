import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class MesGainsScreen extends StatefulWidget {
  const MesGainsScreen({super.key});

  @override
  State<MesGainsScreen> createState() => _MesGainsScreenState();
}

class _MesGainsScreenState extends State<MesGainsScreen> {
  bool _isLoading = true;
  double _totalCommissions = 0;
  List<dynamic> _commissions = [];

  @override
  void initState() {
    super.initState();
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    setState(() => _isLoading = true);
    try {
      final userId = await ApiService.getUserId();
      if (userId != null) {
        final data = await ApiService.getCommissionsCreateur(userId);
        setState(() {
          _totalCommissions = (data['total_commissions'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Mes Gains'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentOrange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total gains card
                  CustomCard(
                    backgroundColor: AppColors.accentOrange,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: AppColors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total des commissions',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_totalCommissions.toStringAsFixed(0)} FCFA',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Détail par groupe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (_commissions.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: AppColors.greyText),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun gain pour le moment',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _commissions.length,
                      itemBuilder: (context, index) {
                        final commission = _commissions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: CustomCard(
                            backgroundColor: AppColors.white,
                            borderRadius: 12,
                            child: ListTile(
                              leading: const Icon(Icons.group, color: AppColors.primaryGreen),
                              title: Text(commission['group_name'] ?? 'Groupe inconnu'),
                              subtitle: Text('${commission['commission_createur']} FCFA'),
                              trailing: Text(
                                commission['created_at'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
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
