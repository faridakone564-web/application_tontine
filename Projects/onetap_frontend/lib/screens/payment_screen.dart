import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class PaymentScreen extends StatefulWidget {
  final int? groupId;
  final String? groupName;
  final double montantGroupe;
  final String reference;

  const PaymentScreen({
    super.key,
    this.groupId,
    this.groupName,
    this.montantGroupe = 0,
    this.reference = '',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const List<String> operators = ['ORANGE', 'MOOV', 'TELECEL'];

  final TextEditingController _telephoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _operatorCode = operators.first;
  bool _isLoading = false;

  @override
  void dispose() {
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _payerAvecMobileMoney() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.groupId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Groupe non spécifié')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await ApiService.getUserId();
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      await ApiService.payerCotisationSimple(
        groupId: widget.groupId!,
        montant: widget.montantGroupe,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paiement en attente de validation')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${error.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _simulerPaiement() async {
    if (widget.groupId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Groupe non spécifié')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await ApiService.getUserId();
      if (userId == null) {
        throw Exception('Utilisateur non connecté');
      }

      final result = await ApiService.simulerPaiement(
        groupId: widget.groupId!,
        montant: widget.montantGroupe,
      );

      if (!mounted) return;
      _showSimulationSuccessDialog(result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: ${error.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSimulationSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(
          Icons.check_circle,
          color: AppColors.primaryGreen,
          size: 64,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paiement simulé avec succès !',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildFeeRow(
              'Montant total',
              '${result['montant_total']?.toStringAsFixed(0) ?? '0'} FCFA',
            ),
            _buildFeeRow(
              'Commission plateforme (1%)',
              '${result['commission_plateforme']?.toStringAsFixed(0) ?? '0'} FCFA',
            ),
            _buildFeeRow(
              'Commission créateur (2%)',
              '${result['commission_createur']?.toStringAsFixed(0) ?? '0'} FCFA',
            ),
            _buildFeeRow(
              'Montant net',
              '${result['montant_net']?.toStringAsFixed(0) ?? '0'} FCFA',
              isBold: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final montant = widget.montantGroupe;
    final fraisPlateforme = montant * 0.01;
    final fraisOrganisateur = montant * 0.02;
    final total = montant + fraisPlateforme + fraisOrganisateur;

    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Paiement'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.groupName != null)
                    Text(
                      widget.groupName!,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 24),
                  _buildFeeRow('Montant', '${montant.toStringAsFixed(0)} FCFA'),
                  _buildFeeRow(
                    'Frais plateforme (1%)',
                    '${fraisPlateforme.toStringAsFixed(0)} FCFA',
                  ),
                  _buildFeeRow(
                    'Frais organisateur (2%)',
                    '${fraisOrganisateur.toStringAsFixed(0)} FCFA',
                  ),
                  const Divider(),
                  _buildFeeRow(
                    'Total',
                    '${total.toStringAsFixed(0)} FCFA',
                    isBold: true,
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _telephoneController,
                          decoration: const InputDecoration(
                            labelText: 'Numéro Mobile Money',
                            hintText: 'Ex: 70 00 00 00',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Numéro requis';
                            }
                            if (value.length < 8) {
                              return 'Numéro invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _operatorCode,
                          decoration: const InputDecoration(
                            labelText: 'Opérateur',
                            prefixIcon: Icon(Icons.sim_card),
                          ),
                          items: operators
                              .map(
                                (op) => DropdownMenuItem(
                                  value: op,
                                  child: Text(op),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(
                              () => _operatorCode = value ?? operators.first,
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        ActionButton(
                          label: 'Payer avec Mobile Money',
                          onPressed: _payerAvecMobileMoney,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 16),
                        ActionButton(
                          label: 'Simuler un paiement',
                          onPressed: _simulerPaiement,
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFeeRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.primaryGreen : null,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.primaryGreen : null,
            ),
          ),
        ],
      ),
    );
  }
}
