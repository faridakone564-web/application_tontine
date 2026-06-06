import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _rejoindreGroupe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ApiService.rejoindreGroupe(
        codeInvitation: _codeController.text.trim().toUpperCase(),
      );

      if (response['message'] != null) {
        setState(() {
          _successMessage = response['message'];
        });

        _formKey.currentState!.reset();
        _codeController.clear();

        // Afficher un message de succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Groupe rejoint avec succès!'),
              backgroundColor: AppColors.primaryGreen,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Retourner après 2 secondes
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        }
      } else {
        setState(() {
          _errorMessage = response['error'] ??
              'Erreur lors de la jonction au groupe';
        });
      }
    } catch (error) {
      final errorMsg = error.toString();
      if (errorMsg.contains('déjà démarré')) {
        setState(() {
          _errorMessage = 'Cette tontine a déjà démarré. Les inscriptions sont fermées.';
        });
      } else if (errorMsg.contains('atteint le nombre maximum')) {
        setState(() {
          _errorMessage = 'Ce groupe a atteint le nombre maximum de membres.';
        });
      } else {
        setState(() {
          _errorMessage = 'Erreur de connexion au serveur';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Rejoindre un Groupe'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Text(
              'Rejoindre un Groupe Tontine',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Entrez le code d\'invitation pour rejoindre un groupe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.greyText,
                  ),
            ),
            const SizedBox(height: 40),

            // Message de succès
            if (_successMessage != null) ...[
              CustomCard(
                backgroundColor: const Color(0xFFF1F8F1),
                borderRadius: 12,
                child: Row(
                  children: const [
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primaryGreen,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Groupe rejoint avec succès!',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Message d'erreur
            if (_errorMessage != null) ...[
              CustomCard(
                backgroundColor: const Color(0xFFFFEBEE),
                borderRadius: 12,
                child: Row(
                  children: [
                    const Icon(
                      Icons.error,
                      color: Color(0xFFD32F2F),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Icône illustration
            Center(
              child: Icon(
                Icons.group_add_rounded,
                size: 80,
                color: AppColors.primaryGreen.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 32),

            // Formulaire
            Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    label: 'Code d\'invitation',
                    hint: 'Entrez le code (ex: ABC12345)',
                    icon: Icons.vpn_key,
                    controller: _codeController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le code d\'invitation est requis';
                      }
                      if (value.trim().length != 8) {
                        return 'Le code doit contenir 8 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Le code a été fourni par le créateur du groupe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.greyText,
                        ),
                  ),
                  const SizedBox(height: 32),
                  ActionButton(
                    label: 'Rejoindre le Groupe',
                    icon: Icons.check,
                    isLoading: _isLoading,
                    onPressed: _rejoindreGroupe,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Conseil
            CustomCard(
              backgroundColor: AppColors.white,
              borderRadius: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.accentOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Conseil',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Assurez-vous que le code fourni est valide et n\'a pas expiré.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
